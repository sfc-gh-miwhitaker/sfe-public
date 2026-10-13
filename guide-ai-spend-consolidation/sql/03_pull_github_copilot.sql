/* Cross-platform AI spend consolidation - GitHub Copilot adapter
   Pair-programmed by SE Community + Cortex Code
   Expires: 2026-11-09

   Worked SINGLE-ORGANIZATION scope. Usage: users-1-day -> all download_links
   (NDJSON). Licensing: /orgs/{org}/copilot/billing/seats. Do not sum usage
   across overlapping organizations. Enterprise-wide licensing requires a
   separately qualified inventory; changing only the URL prefix is not enough.

   AI credits describe consumption, NOT invoicing. This connector publishes
   activity and seat snapshots, not billable overage. No usage-to-money rate
   is applied to GitHub activity by sql/06.
   https://docs.github.com/en/rest/copilot/copilot-usage-metrics
   https://docs.github.com/en/rest/copilot/copilot-user-management
   https://docs.github.com/en/copilot/reference/copilot-usage-metrics/copilot-usage-metrics

   Run the orchestrator directly as AI_SPEND_RL (also the task owner), not through
   an owner-rights wrapper. Both upload ancestors use caller rights. Snowpark
   put_stream uses a stored-procedure upload API, not Session.sql('PUT ...');
   qualify stage upload and COPY in the target runtime before enabling the task.
   Use AUTOCOMMIT=TRUE with no surrounding explicit transaction: caller rollback
   can otherwise discard failure logs as well as landing rows.
   https://docs.snowflake.com/en/developer-guide/stored-procedure/stored-procedures-rights
   https://docs.snowflake.com/en/developer-guide/snowpark/reference/python/latest/snowpark/api/snowflake.snowpark.FileOperation.put_stream
*/
USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;

CREATE OR REPLACE PROCEDURE AI_SPEND.CONTROL.PULL_GITHUB_COPILOT(
  REPORT_NAME VARCHAR, SINCE_TS TIMESTAMP_TZ
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python', 'requests')
HANDLER = 'pull'
EXTERNAL_ACCESS_INTEGRATIONS = (AI_SPEND_EAI)
SECRETS = ('github_token' = AI_SPEND.CONTROL.GITHUB_COPILOT_CREDENTIALS)
EXECUTE AS CALLER
AS
$$
from __future__ import annotations

import io
import json
import math
import re
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from urllib.parse import urlsplit

import _snowflake
import requests
from snowflake.snowpark import Session

PLATFORM_KEY = "GITHUB_COPILOT"
BILLING_CONTEXT = "GITHUB_ENTERPRISE"  # registry contract key; one org per deployment
ORG = "your-organization"
API_ROOT = "https://api.github.com"
API_VERSION = "2026-03-10"
# Populate exact approved report-download hosts in BOTH this set and sql/02's
# network rule. Never learn/trust hosts automatically from a remote response.
DOWNLOAD_HOSTS = frozenset()
FIRST_RUN_DAYS = 28
RESTATEMENT_OVERLAP_DAYS = 3  # qualification choice; verify source revision policy
PUBLICATION_LAG_DAYS = 3    # qualify for the organization, not a vendor SLA
PAGE_SIZE = 100
MAX_PAGES = 500
MAX_REPORT_BYTES = 100 * 1024 * 1024
REPORTS = ("USER_USAGE", "SEATS")


class PullError(Exception):
    """Only locally authored messages from this class may enter the run log."""


def execute(session, sql, params=None, report="CONTROL"):
    # Per-statement parameters work without mutating an owner-rights session.
    return session.sql(sql, params=params).collect(
        statement_params={"QUERY_TAG": f"AI_SPEND:{PLATFORM_KEY}:{report}"}
    )


def log_run(session, values):
    execute(session, """
        INSERT INTO AI_SPEND.CONTROL.PULL_RUN_LOG (
          RUN_ID, PLATFORM_KEY, REPORT_NAME, STARTED_AT, COMPLETED_AT, STATUS,
          FILE_NAME, RECORDS_FETCHED, ROWS_LOADED, WATERMARK_FROM, WATERMARK_TO,
          ERROR_CLASS, ERROR_MESSAGE, QUERY_ID
        ) SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, LAST_QUERY_ID()
    """, values)


def api_json(http, path, headers, params):
    response = http.get(API_ROOT + path, headers=headers, params=params,
                        timeout=120, allow_redirects=False)
    # A redirect or unavailable report is NOT a completed empty snapshot.
    if response.status_code != 200:
        raise PullError(f"GITHUB_HTTP_{response.status_code}")
    return response.json()


def download_records(http, url):
    if not isinstance(url, str) or any(char.isspace() or ord(char) < 32 for char in url):
        raise PullError("UNAPPROVED_DOWNLOAD_URL")
    try:
        parsed = urlsplit(url)
        port = parsed.port
    except ValueError:
        raise PullError("UNAPPROVED_DOWNLOAD_URL") from None
    if (parsed.scheme != "https" or parsed.hostname not in DOWNLOAD_HOSTS
            or port not in (None, 443) or parsed.username or parsed.password
            or parsed.fragment):
        raise PullError("UNAPPROVED_DOWNLOAD_URL")
    # No bearer header, no session auth, no automatic redirects. Never log a
    # signed URL: it is a temporary credential. EAI is the second egress boundary.
    with http.get(url, timeout=120, stream=True, allow_redirects=False) as response:
        if response.status_code != 200:
            raise PullError(f"DOWNLOAD_HTTP_{response.status_code}")
        payload = bytearray()
        for chunk in response.iter_content(chunk_size=65536):
            payload.extend(chunk)
            if len(payload) > MAX_REPORT_BYTES:
                raise PullError("REPORT_TOO_LARGE")
    return [json.loads(line) for line in payload.decode("utf-8").splitlines()
            if line.strip()]


def assert_shape(report, records, report_day=None):
    for record in records:
        if not isinstance(record, dict):
            raise PullError("SCHEMA_DRIFT: expected object")
        if report == "SEATS":
            assignee = record.get("assignee")
            if not isinstance(assignee, dict) or not isinstance(assignee.get("login"), str) or not assignee["login"].strip() or assignee["login"] != assignee["login"].strip():
                raise PullError("SCHEMA_DRIFT: missing assignee login")
            try:
                assigned = datetime.fromisoformat(record["created_at"].replace("Z", "+00:00"))
                if assigned.utcoffset() is None:
                    raise ValueError()
            except (KeyError, TypeError, ValueError, AttributeError):
                raise PullError("SCHEMA_DRIFT: invalid seat created_at") from None
        else:
            if not isinstance(record.get("user_login"), str) or not record["user_login"].strip() or record["user_login"] != record["user_login"].strip():
                raise PullError("SCHEMA_DRIFT: missing user login")
            if record.get("day") != report_day.isoformat():
                raise PullError("SCHEMA_DRIFT: report day mismatch")
            # Validate the fields consumed by shredding, on EVERY record. GitHub
            # documents credits as a number and acceptance activity as an integer.
            credits = record.get("ai_credits_used")
            if (isinstance(credits, bool) or not isinstance(credits, (int, float))
                    or credits < 0 or credits >= 10**32
                    or (isinstance(credits, float) and not math.isfinite(credits))):
                raise PullError("SCHEMA_DRIFT: invalid ai_credits_used")
            # NUMBER(38,6) downstream must not silently round source precision.
            if Decimal(str(credits)).as_tuple().exponent < -6:
                raise PullError("SCHEMA_DRIFT: ai_credits_used exceeds shaped precision")
            activity = record.get("code_acceptance_activity_count")
            if type(activity) is not int or not 0 <= activity < 10**38:
                raise PullError("SCHEMA_DRIFT: invalid code_acceptance_activity_count")


def fetch_seats(http, headers):
    records = []
    expected = None
    for page in range(1, MAX_PAGES + 1):
        payload = api_json(http, f"/orgs/{ORG}/copilot/billing/seats", headers,
                           {"per_page": PAGE_SIZE, "page": page})
        if not isinstance(payload, dict) or not isinstance(payload.get("seats"), list):
            raise PullError("SCHEMA_DRIFT: seats envelope missing")
        total = payload.get("total_seats")
        if isinstance(total, bool) or not isinstance(total, int) or total < 0:
            raise PullError("SCHEMA_DRIFT: total_seats missing")
        if expected is None:
            expected = total
        if total != expected:
            raise PullError("INCOMPLETE_SNAPSHOT: seat total changed while paging")
        batch = payload["seats"]
        assert_shape("SEATS", batch)
        if len(batch) > PAGE_SIZE:
            raise PullError("SCHEMA_DRIFT: seat page exceeds requested size")
        records.extend(batch)
        if len(records) == expected:
            logins = [record["assignee"]["login"].casefold() for record in records]
            if len(set(logins)) != len(logins):
                raise PullError("INCOMPLETE_SNAPSHOT: duplicate assignee")
            return records
        if len(records) > expected or len(batch) < PAGE_SIZE:
            raise PullError("INCOMPLETE_SNAPSHOT: count mismatch")
    raise PullError("PAGINATION_LIMIT: snapshot not complete")


def fetch_usage_day(http, headers, report_day):
    payload = api_json(http, f"/orgs/{ORG}/copilot/metrics/reports/users-1-day",
                       headers, {"day": report_day.isoformat()})
    if (not isinstance(payload, dict) or payload.get("report_day") != report_day.isoformat()
            or not isinstance(payload.get("download_links"), list)
            or not payload["download_links"]):
        raise PullError("INCOMPLETE_SNAPSHOT: missing report download links")
    records = []
    links = payload["download_links"]
    if any(not isinstance(link, str) for link in links) or len(set(links)) != len(links):
        raise PullError("SCHEMA_DRIFT: invalid download links")
    for link in links:
        records.extend(download_records(http, link))
    assert_shape("USER_USAGE", records, report_day)
    subjects = [record["user_login"].casefold() for record in records]
    if len(set(subjects)) != len(subjects):
        raise PullError("SCHEMA_DRIFT: duplicate user/day across report files")
    return records


def land_partition(session, records, report, run_id, report_day, pulled_at):
    loaded = 0
    path = f"github_copilot/{report.lower()}/{report_day:%Y/%m/%d}/{run_id}.jsonl"
    if records:
        buffer = io.BytesIO("\n".join(json.dumps(record, allow_nan=False) for record in records).encode("utf-8"))
        put = session.file.put_stream(buffer, f"@AI_SPEND.RAW.AI_USAGE_STAGE/{path}",
                                      auto_compress=False, overwrite=False)
        if getattr(put, "status", None) != "UPLOADED":
            raise PullError("STAGE_UPLOAD_NOT_COMPLETED")
        result = execute(session, f"""
            COPY INTO AI_SPEND.RAW.LANDING_AI_USAGE (
              PLATFORM_KEY, REPORT_NAME, BILLING_CONTEXT, PULLED_AT,
              SOURCE_FILE, SOURCE_ROW_NUMBER, RECORD, RUN_ID
            ) FROM (
              SELECT ?, ?, ?, ?::TIMESTAMP_TZ, METADATA$FILENAME,
                     METADATA$FILE_ROW_NUMBER, $1, ?
              FROM @AI_SPEND.RAW.AI_USAGE_STAGE/{path}
            ) FILE_FORMAT = (FORMAT_NAME = AI_SPEND.RAW.JSONL_FORMAT)
              ON_ERROR = ABORT_STATEMENT
        """, [PLATFORM_KEY, report, BILLING_CONTEXT, pulled_at, run_id], report)
        counts = []
        for row in result:
            fields = {key.lower(): value for key, value in row.as_dict().items()}
            count = fields.get("rows_loaded")
            if fields.get("status") != "LOADED" or type(count) is not int or count < 0:
                raise PullError("COPY_NOT_COMPLETED")
            counts.append(count)
        loaded = sum(counts)
        if not counts or loaded != len(records):
            raise PullError("COPY_COUNT_MISMATCH")
    # An empty partition is represented here even though no JSON records exist.
    execute(session, """INSERT INTO AI_SPEND.CONTROL.REPORT_SNAPSHOT
        (RUN_ID, PLATFORM_KEY, REPORT_NAME, PARTITION_DATE, RECORD_COUNT)
        SELECT ?, ?, ?, ?::DATE, ?""",
        [run_id, PLATFORM_KEY, report, report_day, len(records)], report)
    return loaded


def pull(session: Session, report_name: str, since_ts):
    run_id = str(uuid.uuid4())
    started = datetime.now(timezone.utc)
    report = "INVALID_REPORT"
    watermark_from = since_ts
    watermark_to = started
    fetched = loaded = 0
    try:
        if isinstance(report_name, str) and report_name.upper() in REPORTS:
            report = report_name.upper()
        if report not in REPORTS or not re.fullmatch(r"[A-Za-z0-9-]+", ORG) or ORG == "your-organization":
            raise PullError("CONFIG: set organization and supported report")
        active = execute(session, """SELECT IS_ACTIVE FROM AI_SPEND.CONTROL.PLATFORM_REGISTRY
            WHERE PLATFORM_KEY = ?""", [PLATFORM_KEY], report)
        if len(active) != 1 or not active[0][0]:
            raise PullError("CONFIG: platform inactive or registry ambiguous")
        if since_ts is not None and (not isinstance(since_ts, datetime) or since_ts.utcoffset() is None):
            raise PullError("CONFIG: watermark must be a timezone-aware timestamp")
        if (type(FIRST_RUN_DAYS) is not int or not 1 <= FIRST_RUN_DAYS <= 28
                or type(RESTATEMENT_OVERLAP_DAYS) is not int or not 1 <= RESTATEMENT_OVERLAP_DAYS <= FIRST_RUN_DAYS
                or type(PUBLICATION_LAG_DAYS) is not int or PUBLICATION_LAG_DAYS < 1
                or type(PAGE_SIZE) is not int or not 1 <= PAGE_SIZE <= 100
                or type(MAX_PAGES) is not int or MAX_PAGES < 1):
            raise PullError("CONFIG: invalid window or pagination limits")
        if report == "USER_USAGE" and not DOWNLOAD_HOSTS:
            raise PullError("CONFIG: approve exact download hosts first")
        token = _snowflake.get_generic_secret_string("github_token")
        headers = {"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json",
                   "X-GitHub-Api-Version": API_VERSION}
        with requests.Session() as http:
            http.trust_env = False  # no implicit .netrc credentials or proxy auth
            if report == "SEATS":
                partitions = [(started.date(), fetch_seats(http, headers))]
                watermark_from = started
            else:
                through_day = started.date() - timedelta(days=PUBLICATION_LAG_DAYS)
                start_day = (since_ts.astimezone(timezone.utc).date() - timedelta(days=RESTATEMENT_OVERLAP_DAYS)
                             if since_ts else through_day - timedelta(days=FIRST_RUN_DAYS - 1))
                if (since_ts is not None and since_ts > datetime.combine(through_day + timedelta(days=1), datetime.min.time(), timezone.utc)):
                    raise PullError("HISTORY_GAP: watermark exceeds completed source day")
                if start_day > through_day or (through_day - start_day).days >= FIRST_RUN_DAYS:
                    raise PullError("HISTORY_GAP: qualify backfill range before advancing watermark")
                watermark_from = datetime.combine(start_day, datetime.min.time(), timezone.utc)
                watermark_to = datetime.combine(through_day + timedelta(days=1), datetime.min.time(), timezone.utc)
                partitions = []
                report_day = start_day
                while report_day <= through_day:
                    records = fetch_usage_day(http, headers, report_day)
                    fetched += len(records)
                    loaded += land_partition(session, records, report, run_id, report_day, started)
                    report_day += timedelta(days=1)
            for report_day, records in partitions:
                fetched += len(records)
                loaded += land_partition(session, records, report, run_id, report_day, started)
        log_run(session, [run_id, PLATFORM_KEY, report, started, datetime.now(timezone.utc),
                         "SUCCEEDED", None, fetched, loaded, watermark_from, watermark_to, None, None])
        return {"run_id": run_id, "status": "SUCCEEDED", "rows_loaded": loaded}
    except Exception as exc:
        # requests exceptions can contain signed URLs/tokens. Store only a controlled
        # error message; never response bodies, remote URLs, or exception strings.
        message = str(exc) if type(exc) is PullError else "Pull failed; inspect controlled error class and requalify configuration/source"
        try:
            log_run(session, [run_id, PLATFORM_KEY, report, started, datetime.now(timezone.utc),
                             "FAILED", None, fetched, loaded, watermark_from, watermark_to,
                             type(exc).__name__, message[:2000]])
        except Exception:
            # If the log itself is inaccessible, still fail without leaking the
            # underlying database exception into task history or the caller.
            raise RuntimeError("GitHub pull failed; failure log unavailable; check control-table privileges") from None
        raise RuntimeError("GitHub pull failed; inspect PULL_RUN_LOG") from None
$$;

/* Current roster is a planning estimate, not a historical invoice reconstruction.
   Preserve any seat observed in the current month as billable for that month;
   do not erase a paid month when a seat is cancelled. A new empty monthly roster
   produces no seats. Historical billed entitlement must come from finance. */
CREATE OR REPLACE PROCEDURE AI_SPEND.CONTROL.PROJECT_GITHUB_SEATS(
  PERIOD_MONTH DATE, SEAT_MONTHLY_COST NUMBER(38,4), CURRENCY_CODE VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  SNAPSHOT_RUN VARCHAR;
  INVALID_CONFIG EXCEPTION (-20102, 'Require current month, valid seat rate/currency and completed current-month seat snapshot');
BEGIN
  IF (PERIOD_MONTH <> DATE_TRUNC('month', CURRENT_DATE()) OR PERIOD_MONTH IS NULL
      OR SEAT_MONTHLY_COST IS NULL OR SEAT_MONTHLY_COST < 0
      OR CURRENCY_CODE IS NULL OR NOT REGEXP_LIKE(CURRENCY_CODE, '[A-Z]{3}')) THEN
    RAISE INVALID_CONFIG;
  END IF;
  SELECT s.RUN_ID INTO :SNAPSHOT_RUN
  FROM AI_SPEND.CONTROL.REPORT_SNAPSHOT s
  JOIN AI_SPEND.CONTROL.PULL_RUN_LOG r
    ON r.RUN_ID = s.RUN_ID AND r.PLATFORM_KEY = s.PLATFORM_KEY
   AND r.REPORT_NAME = s.REPORT_NAME AND r.STATUS = 'SUCCEEDED'
  WHERE s.PLATFORM_KEY = 'GITHUB_COPILOT' AND s.REPORT_NAME = 'SEATS'
    AND s.PARTITION_DATE >= :PERIOD_MONTH
    AND s.PARTITION_DATE < DATEADD('month', 1, :PERIOD_MONTH)
  QUALIFY ROW_NUMBER() OVER (ORDER BY r.COMPLETED_AT DESC, s.RUN_ID DESC) = 1;
  IF (SNAPSHOT_RUN IS NULL) THEN RAISE INVALID_CONFIG; END IF;

  MERGE INTO AI_SPEND.CONTROL.SEAT_ENTITLEMENT target
  USING (
    WITH resolved AS (
      SELECT l.RECORD:assignee:login::VARCHAR AS SUBJECT_KEY,
             COALESCE(m.PERSON_KEY, 'UNRESOLVED:GITHUB_COPILOT:' || l.RECORD:assignee:login::VARCHAR) AS PERSON_KEY,
             TRY_TO_TIMESTAMP_TZ(l.RECORD:created_at::VARCHAR) AS ASSIGNED_AT
      FROM AI_SPEND.RAW.LANDING_AI_USAGE l
      LEFT JOIN AI_SPEND.CONTROL.IDENTITY_MAP m
        ON m.PLATFORM_KEY = l.PLATFORM_KEY
       AND m.SUBJECT_KEY = l.RECORD:assignee:login::VARCHAR
       AND :PERIOD_MONTH BETWEEN m.VALID_FROM AND m.VALID_TO
      WHERE l.RUN_ID = :SNAPSHOT_RUN AND l.PLATFORM_KEY = 'GITHUB_COPILOT'
        AND l.REPORT_NAME = 'SEATS'
      QUALIFY ROW_NUMBER() OVER (PARTITION BY l.RECORD:assignee:login::VARCHAR
        ORDER BY m.VALID_FROM DESC NULLS LAST, m.UPDATED_AT DESC NULLS LAST) = 1
    )
    SELECT PERSON_KEY, MIN(ASSIGNED_AT) AS ASSIGNED_AT,
           COUNT(*) * :SEAT_MONTHLY_COST AS MONTHLY_COST
    FROM resolved GROUP BY PERSON_KEY
  ) source
  ON target.PLATFORM_KEY = 'GITHUB_COPILOT'
    AND target.PERSON_KEY = source.PERSON_KEY AND target.PERIOD_MONTH = :PERIOD_MONTH
  -- Never replace finance actuals with a roster estimate or leave a finance
  -- provenance label on an amount calculated from the roster.
  WHEN MATCHED AND target.SOURCE_NAME = 'GITHUB_ROSTER_ESTIMATE' THEN UPDATE SET
    target.SEAT_MONTHLY_COST = source.MONTHLY_COST,
    target.CURRENCY_CODE = :CURRENCY_CODE,
    target.IS_ACTIVE_IN_PERIOD = TRUE,
    target.SOURCE_RUN_ID = :SNAPSHOT_RUN,
    target.CAPTURED_AT = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT (
    PLATFORM_KEY, PERSON_KEY, PERIOD_MONTH, SEAT_MONTHLY_COST, CURRENCY_CODE,
    ASSIGNED_AT, IS_ACTIVE_IN_PERIOD, SOURCE_NAME, SOURCE_RUN_ID
  ) VALUES ('GITHUB_COPILOT', source.PERSON_KEY, :PERIOD_MONTH, source.MONTHLY_COST,
            :CURRENCY_CODE, source.ASSIGNED_AT, TRUE, 'GITHUB_ROSTER_ESTIMATE', :SNAPSHOT_RUN);
  RETURN 'Current-month roster estimate projected; reconcile billed entitlements before reclaim decisions.';
END;
$$;

-- Caller rights throughout the upload call chain; task runs as AI_SPEND_RL.
-- Manual callers need the underlying registry, run-log, manifest, stage and
-- landing privileges, not merely USAGE on this procedure. No upload elevation;
-- the subsequent seat projection is a separate owner-rights procedure.
CREATE OR REPLACE PROCEDURE AI_SPEND.CONTROL.PULL_GITHUB_ALL()
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  PULL_FAILURE EXCEPTION (-20101, 'GitHub pull or seat projection failed; inspect report logs and SEAT_RATE');
  CURRENT_REPORT VARCHAR;
  WATERMARK TIMESTAMP_TZ;
  RESULT VARIANT;
  FAILED NUMBER DEFAULT 0;
  RATE_COUNT NUMBER;
  MONTHLY_RATE NUMBER(38,4);
  RATE_CURRENCY VARCHAR;
BEGIN
  -- Let each pull log and raise inactive/missing/ambiguous registry failures.
  FOR REPORT_ROW IN (SELECT COLUMN1 AS REPORT_NAME FROM VALUES ('USER_USAGE'), ('SEATS')) DO
    CURRENT_REPORT := REPORT_ROW.REPORT_NAME;
    SELECT MAX(WATERMARK_TO) INTO :WATERMARK FROM AI_SPEND.CONTROL.PULL_RUN_LOG
    WHERE PLATFORM_KEY = 'GITHUB_COPILOT' AND REPORT_NAME = :CURRENT_REPORT AND STATUS = 'SUCCEEDED';
    BEGIN
      CALL AI_SPEND.CONTROL.PULL_GITHUB_COPILOT(:CURRENT_REPORT, :WATERMARK) INTO :RESULT;
    EXCEPTION WHEN OTHER THEN FAILED := FAILED + 1;
    END;
  END FOR;
  IF (FAILED > 0) THEN RAISE PULL_FAILURE; END IF;
  SELECT COUNT(*), MAX(SEAT_MONTHLY_COST), MAX(CURRENCY_CODE)
    INTO :RATE_COUNT, :MONTHLY_RATE, :RATE_CURRENCY
  FROM AI_SPEND.CONTROL.SEAT_RATE
  WHERE PLATFORM_KEY = 'GITHUB_COPILOT' AND PERIOD_MONTH = DATE_TRUNC('month', CURRENT_DATE());
  IF (RATE_COUNT <> 1) THEN RAISE PULL_FAILURE; END IF;
  CALL AI_SPEND.CONTROL.PROJECT_GITHUB_SEATS(DATE_TRUNC('month', CURRENT_DATE()), :MONTHLY_RATE, :RATE_CURRENCY);
  RETURN OBJECT_CONSTRUCT('status', 'SUCCEEDED');
END;
$$;

-- Create once, then maintain in place. Explicitly leave suspended on rerun.
CREATE TASK IF NOT EXISTS AI_SPEND.CONTROL.TASK_PULL_GITHUB_COPILOT
  WAREHOUSE = AI_SPEND_WH
  SCHEDULE = 'USING CRON 0 7 * * * UTC'
  QUERY_TAG = 'AI_SPEND:GITHUB_COPILOT:ORCHESTRATOR'
AS CALL AI_SPEND.CONTROL.PULL_GITHUB_ALL();
ALTER TASK AI_SPEND.CONTROL.TASK_PULL_GITHUB_COPILOT SUSPEND;
ALTER TASK AI_SPEND.CONTROL.TASK_PULL_GITHUB_COPILOT MODIFY AS
  CALL AI_SPEND.CONTROL.PULL_GITHUB_ALL();

/* Before activation: set ORG; approve exact download hosts in handler and EAI;
   create the secret using sql/02; seed dated identities and this month's SEAT_RATE.
   In a qualification environment set IS_ACTIVE = TRUE while the task stays suspended,
   CALL PULL_GITHUB_ALL(), and reconcile complete daily reports and seat snapshots.
   Only then approve/resume the schedule. Re-run controlled pulls for old rows with
   no RUN_ID: legacy landing rows are retained but cannot publish without manifests.
   Never manufacture completion manifests from MAX/MIN landed event dates. */
