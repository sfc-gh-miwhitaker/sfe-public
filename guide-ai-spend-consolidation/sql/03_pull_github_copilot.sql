/* Cross-platform AI spend consolidation — GitHub Copilot adapter
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   THE reference adapter. Every other platform follows this shape, so read this one
   before writing another. It demonstrates all six obligations in
   docs/adapter-contract.md, and it is the only adapter in this guide that is
   fully implemented -- deliberately. Five hand-maintained vendor connectors rot;
   one worked example plus a contract does not.

   GitHub was chosen because it exercises BOTH cost models in a single platform:
     - usage report: per-user AI credits, a METERED signal
     - seat report:  per-user license state, a SEAT signal
   Those come from two DIFFERENT APIs, which is itself the lesson.

   Pulls two reports:
     USER_USAGE  user-level metrics -> RAW.LANDING_AI_USAGE
     SEATS       seat assignments   -> RAW.LANDING_AI_USAGE and SEAT_ENTITLEMENT

   Note: the legacy Copilot metrics API was retired in April 2026. Sample code and
   blog posts predating that will not run. Verify endpoint paths and the report
   catalog against GitHub's current documentation before your first run -- the
   response shape below is the illustrative target, not a guarantee.
*/

USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;

CREATE OR REPLACE PROCEDURE AI_SPEND.CONTROL.PULL_GITHUB_COPILOT(
  REPORT_NAME VARCHAR,
  SINCE_TS    TIMESTAMP_TZ
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python', 'requests')
HANDLER = 'pull'
EXTERNAL_ACCESS_INTEGRATIONS = (AI_SPEND_EAI)
/* Obligation 2: SECRETS aliases are static DDL. This clause cannot be driven from
   PLATFORM_REGISTRY at runtime -- it is the one place the design is not
   data-driven, and adding a platform means editing a procedure. */
SECRETS = (
  'github_token' = AI_SPEND.CONTROL.GITHUB_COPILOT_CREDENTIALS
)
EXECUTE AS CALLER
AS
$$
from __future__ import annotations

import io
import json
import uuid
from datetime import datetime, timedelta, timezone

import _snowflake
import requests
from snowflake.snowpark import Session


PLATFORM_KEY = "GITHUB_COPILOT"
BILLING_CONTEXT = "GITHUB_ENTERPRISE"
API_ROOT = "https://api.github.com"
API_VERSION = "2022-11-28"

# Set to your enterprise slug or organization login. Enterprise scope is preferred:
# organization-scoped metrics attribute a seated user's activity to EVERY org they
# belong to, so summing across organizations double counts people.
SCOPE_KIND = "enterprises"          # 'enterprises' or 'orgs'
SCOPE_SLUG = "your-enterprise-slug"

# First-run window. Deliberately small -- these reports have short retention and
# unforgiving rate limits, and a wide first pull is the fastest way to get throttled.
FIRST_RUN_DAYS = 28

# Obligation 1, restated: usage reports are daily aggregates that can be RESTATED
# for a couple of days after first publication. Resuming exactly at the watermark
# silently misses those restatements, so overlap and let the SHAPED layer dedup.
RESTATEMENT_OVERLAP_DAYS = 3

PAGE_SIZE = 100
MAX_PAGES = 500      # hard stop; a pagination bug must not loop forever

# Obligation 5: assert on what the normalization layer REQUIRES, and nothing more.
# Asserting on optional fields turns every vendor improvement into an outage.
REQUIRED_FIELDS = {
    "USER_USAGE": {"date", "user_login"},
    "SEATS": {"assignee"},
}

REPORTS = {
    "USER_USAGE": {
        "path": "/copilot/metrics/users",
        "windowed": True,
        "records_key": None,        # response is a bare JSON array
    },
    "SEATS": {
        "path": "/copilot/billing/seats",
        "windowed": False,          # current state, not a time window
        "records_key": "seats",     # records nested under this key
    },
}


def log_run(session: Session, values: list) -> None:
    """Obligation 4: one row on BOTH paths. Without failure rows you cannot tell
    'no usage yesterday' from 'this adapter has been dead for a week'."""
    session.sql(
        """
        INSERT INTO AI_SPEND.CONTROL.PULL_RUN_LOG (
          RUN_ID, PLATFORM_KEY, REPORT_NAME, STARTED_AT, COMPLETED_AT, STATUS,
          FILE_NAME, RECORDS_FETCHED, ROWS_LOADED,
          WATERMARK_FROM, WATERMARK_TO, ERROR_CLASS, ERROR_MESSAGE, QUERY_ID
        ) SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, LAST_QUERY_ID()
        """,
        params=values,
    ).collect()


def fetch_all_pages(http, url: str, headers: dict, params: dict, records_key):
    """Paginate until exhausted. Fails loudly on a bad status rather than
    returning a short result that would look like a quiet day."""
    records = []
    page = 1
    while page <= MAX_PAGES:
        query = dict(params)
        query.update({"per_page": PAGE_SIZE, "page": page})
        response = http.get(url, headers=headers, params=query, timeout=120)

        # 422 on these endpoints usually means the scope has too few seated users
        # for GitHub to return data rather than a malformed request. Surface it as
        # a distinct, readable failure instead of a bare HTTP error.
        if response.status_code == 422:
            raise RuntimeError(
                f"GITHUB_UNPROCESSABLE: {url} returned 422. Common cause: the scope "
                f"has too few seated users for metrics to be published."
            )
        response.raise_for_status()

        payload = response.json()
        batch = payload if records_key is None else payload.get(records_key, [])
        if not isinstance(batch, list):
            raise RuntimeError(
                f"SCHEMA_DRIFT: expected a list at "
                f"{records_key or 'response root'}, got {type(batch).__name__}"
            )
        if not batch:
            break
        records.extend(batch)
        if len(batch) < PAGE_SIZE:
            break
        page += 1
    return records


def assert_shape(report_name: str, records: list) -> None:
    """Obligation 5. A permissive adapter maps a renamed field to NULL and the
    chart keeps drawing a plausible line at the wrong value. Prefer the visible
    failure: fail the pull, let the health view go stale, make someone look."""
    required = REQUIRED_FIELDS[report_name]
    if not records:
        return                       # zero records is legitimate, not drift
    sample = records[0]
    if not isinstance(sample, dict):
        raise RuntimeError(f"SCHEMA_DRIFT: {report_name} records are not objects")
    missing = required - set(sample.keys())
    if missing:
        raise RuntimeError(
            f"SCHEMA_DRIFT: {PLATFORM_KEY}/{report_name} missing required "
            f"{sorted(missing)}; got {sorted(sample.keys())}"
        )


def pull(session: Session, report_name: str, since_ts):
    run_id = str(uuid.uuid4())
    started_at = datetime.now(timezone.utc)
    report_name = (report_name or "").upper()

    if report_name not in REPORTS:
        raise ValueError(
            f"CONFIG: unsupported report {report_name}; expected {sorted(REPORTS)}"
        )
    report = REPORTS[report_name]

    # Obligation 6: make this pipeline's own Snowflake cost attributable. A
    # cost-visibility pipeline that cannot report its own cost is not a good look.
    session.sql(
        f"ALTER SESSION SET QUERY_TAG = 'AI_SPEND:{PLATFORM_KEY}:{report_name}'"
    ).collect()

    watermark_to = datetime.now(timezone.utc)
    file_name = None

    try:
        # --- Obligation 2: credentials from a Snowflake secret, never a parameter
        token = _snowflake.get_generic_secret_string("github_token")
        headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": API_VERSION,
        }

        # --- Obligation 1: watermark, with restatement overlap
        params = {}
        watermark_from = since_ts
        if report["windowed"]:
            if since_ts is None:
                start = watermark_to - timedelta(days=FIRST_RUN_DAYS)
            else:
                start = since_ts.astimezone(timezone.utc) - timedelta(
                    days=RESTATEMENT_OVERLAP_DAYS
                )
            watermark_from = start
            params = {
                "since": start.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "until": watermark_to.strftime("%Y-%m-%dT%H:%M:%SZ"),
            }

        url = f"{API_ROOT}/{SCOPE_KIND}/{SCOPE_SLUG}{report['path']}"
        with requests.Session() as http:
            records = fetch_all_pages(
                http, url, headers, params, report["records_key"]
            )

        assert_shape(report_name, records)

        # --- Obligation 3: stage first, then COPY. Leaves an immutable copy of
        # exactly what the vendor returned, which is what lets a shredding bug be
        # fixed without a re-pull and what settles a disputed number later.
        rows_loaded = 0
        if records:
            buffer = io.BytesIO(
                "\n".join(json.dumps(r) for r in records).encode("utf-8")
            )
            path = (
                f"{PLATFORM_KEY.lower()}/{report_name.lower()}/"
                f"{watermark_to:%Y/%m/%d}/{run_id}.jsonl"
            )
            session.file.put_stream(
                buffer,
                f"@AI_SPEND.RAW.AI_USAGE_STAGE/{path}",
                auto_compress=False,
                overwrite=False,     # a run_id collision must fail, not overwrite evidence
            )
            file_name = path

            copy_result = session.sql(
                f"""
                COPY INTO AI_SPEND.RAW.LANDING_AI_USAGE (
                  PLATFORM_KEY, REPORT_NAME, BILLING_CONTEXT, PULLED_AT,
                  SOURCE_FILE, SOURCE_ROW_NUMBER, RECORD
                )
                FROM (
                  SELECT ?, ?, ?, ?::TIMESTAMP_TZ,
                         METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, $1
                  FROM @AI_SPEND.RAW.AI_USAGE_STAGE/{path}
                )
                FILE_FORMAT = (FORMAT_NAME = AI_SPEND.RAW.JSONL_FORMAT)
                ON_ERROR = ABORT_STATEMENT
                """,
                params=[PLATFORM_KEY, report_name, BILLING_CONTEXT, watermark_to],
            ).collect()
            rows_loaded = sum(
                int(
                    row.as_dict().get(
                        "ROWS_LOADED", row.as_dict().get("rows_loaded", 0)
                    )
                )
                for row in copy_result
            )

        log_run(session, [
            run_id, PLATFORM_KEY, report_name, started_at,
            datetime.now(timezone.utc), "SUCCEEDED", file_name,
            len(records), rows_loaded, watermark_from, watermark_to, None, None,
        ])

        return {
            "run_id": run_id,
            "status": "SUCCEEDED",
            "platform_key": PLATFORM_KEY,
            "report_name": report_name,
            "records_fetched": len(records),
            "rows_loaded": rows_loaded,
            "file_name": file_name,
        }

    except Exception as exc:
        log_run(session, [
            run_id, PLATFORM_KEY, report_name, started_at,
            datetime.now(timezone.utc), "FAILED", file_name,
            None, None, since_ts, watermark_to,
            type(exc).__name__, str(exc)[:16000],
        ])
        # Re-raise. A swallowed exception leaves the task green and the data stale --
        # the single worst outcome available to a pipeline like this.
        raise
$$;

-- ---------------------------------------------------------------------------
-- Orchestrator: both reports, watermark resolved per report
--
-- Counts outcomes and RAISEs if anything failed, so the task goes red. Per-report
-- exception handling means one broken report does not prevent the other from
-- landing -- partial data plus a red task beats no data plus a red task.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE AI_SPEND.CONTROL.PULL_GITHUB_ALL()
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  PULL_FAILURE EXCEPTION (-20101,
    'One or more GitHub Copilot report pulls failed; inspect PULL_RUN_LOG');
  CURRENT_REPORT VARCHAR;
  WATERMARK TIMESTAMP_TZ;
  RESULT VARIANT;
  SUCCEEDED NUMBER DEFAULT 0;
  FAILED NUMBER DEFAULT 0;
BEGIN
  FOR REPORT_ROW IN (
    SELECT COLUMN1 AS REPORT_NAME FROM VALUES ('USER_USAGE'), ('SEATS')
  ) DO
    CURRENT_REPORT := REPORT_ROW.REPORT_NAME;
    WATERMARK := (
      SELECT MAX(WATERMARK_TO)
      FROM AI_SPEND.CONTROL.PULL_RUN_LOG
      WHERE PLATFORM_KEY = 'GITHUB_COPILOT'
        AND REPORT_NAME = :CURRENT_REPORT
        AND STATUS = 'SUCCEEDED'
    );
    BEGIN
      CALL AI_SPEND.CONTROL.PULL_GITHUB_COPILOT(:CURRENT_REPORT, :WATERMARK)
        INTO :RESULT;
      SUCCEEDED := SUCCEEDED + 1;
    EXCEPTION
      WHEN OTHER THEN
        FAILED := FAILED + 1;
    END;
  END FOR;

  IF (FAILED > 0) THEN
    RAISE PULL_FAILURE;
  END IF;
  RETURN OBJECT_CONSTRUCT('succeeded', SUCCEEDED, 'failed', FAILED);
END;
$$;

-- ---------------------------------------------------------------------------
-- Seat entitlement projection
--
-- Why this is separate from the usage fact: a seat costs the same whether the
-- person used it 400 times or zero times. Folding it into an activity row would
-- make cost move with behaviour that does not change the bill.
--
-- SEAT_MONTHLY_COST is a PARAMETER, not something the API returns. Per-seat price
-- is contractual and usually discounted off list. Pass your real negotiated rate;
-- a list-price default would produce a confidently wrong number.
--
-- IS_ACTIVE_IN_PERIOD carries the whole value of this table: a TRUE row with no
-- matching usage is a license you are paying for that nobody touches.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE AI_SPEND.CONTROL.PROJECT_GITHUB_SEATS(
  PERIOD_MONTH      DATE,
  SEAT_MONTHLY_COST NUMBER(38,4),
  CURRENCY_CODE     VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  SEATS_WRITTEN NUMBER;
BEGIN
  MERGE INTO AI_SPEND.CONTROL.SEAT_ENTITLEMENT AS tgt
  USING (
    WITH current_pull AS (
      /* Scope to the MOST RECENT pull only. Ranking over all history would keep a
         departed person's last-ever seat record winning forever, so they would be
         billed in every future month and committed seat cost would only ever grow. */
      SELECT MAX(PULLED_AT) AS LATEST_PULLED_AT
      FROM AI_SPEND.RAW.LANDING_AI_USAGE
      WHERE PLATFORM_KEY = 'GITHUB_COPILOT'
        AND REPORT_NAME = 'SEATS'
    ),
    latest AS (
      SELECT
        l.RECORD,
        -- One row per assignee: the API returns current state, and an overlapping
        -- pull window means the same seat lands more than once.
        ROW_NUMBER() OVER (
          PARTITION BY l.RECORD:assignee:login::VARCHAR
          ORDER BY l.PULLED_AT DESC, l.SOURCE_ROW_NUMBER DESC
        ) AS rn
      FROM AI_SPEND.RAW.LANDING_AI_USAGE l
      CROSS JOIN current_pull c
      WHERE l.PLATFORM_KEY = 'GITHUB_COPILOT'
        AND l.REPORT_NAME = 'SEATS'
        AND l.RECORD:assignee:login IS NOT NULL
        AND l.PULLED_AT = c.LATEST_PULLED_AT
    )
    SELECT
      /* MUST match the UNRESOLVED format built in sql/06_normalize.sql exactly:
         'UNRESOLVED:' || PLATFORM_KEY || ':' || SUBJECT_KEY. If these two drift
         apart, seat rows never join to usage rows, every unresolved seat reads as
         DORMANT, and the reclaimable-cost figure is fabricated. */
      COALESCE(m.PERSON_KEY,
               'UNRESOLVED:GITHUB_COPILOT:' || l.RECORD:assignee:login::VARCHAR)
        AS PERSON_KEY,
      TRY_TO_TIMESTAMP_TZ(l.RECORD:created_at::VARCHAR) AS ASSIGNED_AT,
      /* A seat with a pending cancellation is still billed for the current period,
         so it stays TRUE here. Treating it as inactive would understate committed
         spend in exactly the month someone is trying to forecast. */
      TRUE AS IS_ACTIVE_IN_PERIOD
    FROM latest l
    LEFT JOIN AI_SPEND.CONTROL.IDENTITY_MAP m
      ON  m.PLATFORM_KEY = 'GITHUB_COPILOT'
     AND m.SUBJECT_KEY = l.RECORD:assignee:login::VARCHAR
     AND :PERIOD_MONTH BETWEEN m.VALID_FROM AND m.VALID_TO
    WHERE l.rn = 1
    /* Collapse to one row per PERSON_KEY. Two GitHub logins mapping to one person
       is expected -- and without this the MERGE either inserts a duplicate seat
       (first run, since the PK is declared but NOT enforced) or fails with a
       nondeterministic-merge error (later runs).

       NOTE: if two seats for one person is a real billing situation for you, the
       right fix is the opposite -- add SUBJECT_KEY to the SEAT_ENTITLEMENT primary
       key so both charges are counted. */
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY PERSON_KEY ORDER BY ASSIGNED_AT DESC NULLS LAST
    ) = 1
  ) AS src
  ON  tgt.PLATFORM_KEY = 'GITHUB_COPILOT'
  AND tgt.PERSON_KEY = src.PERSON_KEY
  AND tgt.PERIOD_MONTH = :PERIOD_MONTH
  WHEN MATCHED THEN UPDATE SET
    tgt.SEAT_MONTHLY_COST = :SEAT_MONTHLY_COST,
    tgt.CURRENCY_CODE = :CURRENCY_CODE,
    tgt.ASSIGNED_AT = src.ASSIGNED_AT,
    tgt.IS_ACTIVE_IN_PERIOD = src.IS_ACTIVE_IN_PERIOD,
    tgt.CAPTURED_AT = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT (
    PLATFORM_KEY, PERSON_KEY, PERIOD_MONTH, SEAT_MONTHLY_COST, CURRENCY_CODE,
    ASSIGNED_AT, IS_ACTIVE_IN_PERIOD, SOURCE_NAME
  ) VALUES (
    'GITHUB_COPILOT', src.PERSON_KEY, :PERIOD_MONTH, :SEAT_MONTHLY_COST,
    :CURRENCY_CODE, src.ASSIGNED_AT, src.IS_ACTIVE_IN_PERIOD,
    'GITHUB_COPILOT_SEATS_API'
  );

  SEATS_WRITTEN := SQLROWCOUNT;

  /* Retire seats that disappeared from the vendor. MERGE has no NOT MATCHED BY
     SOURCE in Snowflake, so this is a separate UPDATE. Without it a departed
     employee stays billable in this table forever. */
  UPDATE AI_SPEND.CONTROL.SEAT_ENTITLEMENT
     SET IS_ACTIVE_IN_PERIOD = FALSE,
         CAPTURED_AT = CURRENT_TIMESTAMP()
   WHERE PLATFORM_KEY = 'GITHUB_COPILOT'
     AND PERIOD_MONTH = :PERIOD_MONTH
     AND CAPTURED_AT < DATEADD('minute', -1, CURRENT_TIMESTAMP())
     AND PERSON_KEY NOT IN (
       SELECT COALESCE(m.PERSON_KEY,
                       'UNRESOLVED:GITHUB_COPILOT:' || r.RECORD:assignee:login::VARCHAR)
       FROM AI_SPEND.RAW.LANDING_AI_USAGE r
       LEFT JOIN AI_SPEND.CONTROL.IDENTITY_MAP m
         ON  m.PLATFORM_KEY = 'GITHUB_COPILOT'
        AND m.SUBJECT_KEY = r.RECORD:assignee:login::VARCHAR
        AND :PERIOD_MONTH BETWEEN m.VALID_FROM AND m.VALID_TO
       WHERE r.PLATFORM_KEY = 'GITHUB_COPILOT'
         AND r.REPORT_NAME = 'SEATS'
         AND r.RECORD:assignee:login IS NOT NULL
         AND r.PULLED_AT = (
           SELECT MAX(PULLED_AT) FROM AI_SPEND.RAW.LANDING_AI_USAGE
           WHERE PLATFORM_KEY = 'GITHUB_COPILOT' AND REPORT_NAME = 'SEATS'
         )
     );

  RETURN 'Seat entitlement rows written for ' || :PERIOD_MONTH::VARCHAR
         || ': ' || :SEATS_WRITTEN::VARCHAR
         || '. Seats absent from the latest pull were retired.';
END;
$$;

-- ---------------------------------------------------------------------------
-- Scheduled pull -- ships SUSPENDED
--
-- Daily rather than hourly: these reports are daily aggregates, so a faster
-- schedule burns rate limit for no additional information.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE TASK AI_SPEND.CONTROL.TASK_PULL_GITHUB_COPILOT
  WAREHOUSE = AI_SPEND_WH
  SCHEDULE = 'USING CRON 0 7 * * * UTC'
  COMMENT = 'Daily GitHub Copilot usage and seat pull'
AS
  CALL AI_SPEND.CONTROL.PULL_GITHUB_ALL();

/* Before resuming, do all four:
     1. Set SCOPE_KIND and SCOPE_SLUG in the Python handler above.
     2. Create GITHUB_COPILOT_CREDENTIALS (see sql/02) and grant READ.
     3. Run one pull by hand and inspect the landed records:

          CALL AI_SPEND.CONTROL.PULL_GITHUB_COPILOT('USER_USAGE', NULL);

          SELECT REPORT_NAME, RECORD
          FROM AI_SPEND.RAW.LANDING_AI_USAGE
          WHERE PLATFORM_KEY = 'GITHUB_COPILOT'
          LIMIT 5;

        Confirm the field names match what sql/06_normalize.sql reads. This is the
        step that catches vendor drift before it reaches a dashboard.
     4. Seed IDENTITY_MAP with GitHub logins, then check the unresolved rate in
        CONTROL.V_PIPELINE_HEALTH. A new platform landing entirely in UNRESOLVED
        shows correct platform totals and a department chart missing a whole tool.

   Then:
     UPDATE AI_SPEND.CONTROL.PLATFORM_REGISTRY
       SET IS_ACTIVE = TRUE WHERE PLATFORM_KEY = 'GITHUB_COPILOT';
     ALTER TASK AI_SPEND.CONTROL.TASK_PULL_GITHUB_COPILOT RESUME;
*/
