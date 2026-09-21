/* Cross-platform AI spend consolidation — monitoring
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   The failure mode this file exists to catch is NOT an adapter that errors loudly.
   It is an adapter that quietly stops returning rows, or starts returning rows with
   a renamed field mapped to NULL, while every dashboard keeps drawing a plausible
   flat line.

   A missing feed must LOOK BROKEN. That is the whole design goal here.

   Four things are watched:
     1. Freshness per platform, against the registry's declared expectation
     2. Identity resolution rate, because unattributed spend breaks allocation
     3. Adapter drift, via error classes in the run log
     4. This pipeline's own Snowflake cost, via its QUERY_TAG
*/

USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;

-- ---------------------------------------------------------------------------
-- CONTROL.V_PIPELINE_HEALTH -- the one view to check every morning
--
-- Driven from PLATFORM_REGISTRY rather than from the run log, so a platform that
-- has NEVER successfully pulled still appears, as a row with no data. Driving it
-- from the log would make a permanently broken adapter invisible: no log rows, no
-- health row, no alarm.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW AI_SPEND.CONTROL.V_PIPELINE_HEALTH
  COMMENT = 'Per-platform freshness, success, identity quality, and drift. Check daily.'
AS
WITH last_success AS (
    /* Grouped by PLATFORM AND REPORT, then reduced to the WORST report.

       Grouping by platform alone hides a dead report behind a healthy one: GitHub
       pulls two reports, and if SEATS has failed for a month while USER_USAGE
       succeeds daily, the platform would read HEALTHY while seat cost silently
       froze. That is exactly the failure this file exists to catch. */
    SELECT
        PLATFORM_KEY,
        MIN(LAST_SUCCESS_AT)    AS LAST_SUCCESS_AT,
        MIN(LAST_WATERMARK)     AS LAST_WATERMARK,
        COUNT(*)                AS REPORTS_SEEN,
        MIN_BY(REPORT_NAME, LAST_SUCCESS_AT) AS STALEST_REPORT
    FROM (
        SELECT
            PLATFORM_KEY,
            REPORT_NAME,
            MAX(COMPLETED_AT)   AS LAST_SUCCESS_AT,
            MAX(WATERMARK_TO)   AS LAST_WATERMARK
        FROM AI_SPEND.CONTROL.PULL_RUN_LOG
        WHERE STATUS = 'SUCCEEDED'
        GROUP BY PLATFORM_KEY, REPORT_NAME
    )
    GROUP BY PLATFORM_KEY
),
recent_runs AS (
    SELECT
        PLATFORM_KEY,
        COUNT(*)                            AS RUNS_7D,
        COUNT_IF(STATUS = 'FAILED')         AS FAILURES_7D,
        -- MAX_BY, not MAX: MAX would return the alphabetically largest error class
        -- rather than the most recent one.
        MAX_BY(IFF(STATUS = 'FAILED', ERROR_CLASS, NULL), STARTED_AT)
                                            AS LATEST_ERROR_CLASS,
        SUM(COALESCE(ROWS_LOADED, 0))       AS ROWS_LOADED_7D
    FROM AI_SPEND.CONTROL.PULL_RUN_LOG
    WHERE STARTED_AT >= DATEADD('day', -7, CURRENT_TIMESTAMP())
    GROUP BY PLATFORM_KEY
),
/* Rows that landed but could not be shredded, because the vendor date or subject
   field did not parse. sql/06 filters these out of the fact, so without this
   counter the loss is invisible -- a renamed field would just quietly shrink the
   data while every chart kept drawing. */
unshreddable AS (
    SELECT PLATFORM_KEY, COUNT(*) AS UNSHREDDABLE_ROWS
    FROM (
        SELECT PLATFORM_KEY, USAGE_DATE, SUBJECT_KEY FROM AI_SPEND.SHAPED.V_SHRED_GITHUB_COPILOT
        UNION ALL
        SELECT PLATFORM_KEY, USAGE_DATE, SUBJECT_KEY FROM AI_SPEND.SHAPED.V_SHRED_CHATGPT_ENTERPRISE
        UNION ALL
        SELECT PLATFORM_KEY, USAGE_DATE, SUBJECT_KEY FROM AI_SPEND.SHAPED.V_SHRED_M365_COPILOT
        UNION ALL
        SELECT PLATFORM_KEY, USAGE_DATE, SUBJECT_KEY FROM AI_SPEND.SHAPED.V_SHRED_BOX_AI
    )
    WHERE USAGE_DATE IS NULL OR SUBJECT_KEY IS NULL
    GROUP BY PLATFORM_KEY
),
fact_state AS (
    SELECT
        PLATFORM_KEY,
        MAX(USAGE_DATE)                     AS LATEST_USAGE_DATE,
        COUNT(*)                            AS FACT_ROWS,
        COUNT(DISTINCT PERSON_KEY)          AS DISTINCT_PEOPLE,
        ROUND(100 * COUNT_IF(IDENTITY_CONFIDENCE = 'NONE')
              / NULLIF(COUNT(*), 0), 2)     AS UNRESOLVED_PCT
    FROM AI_SPEND.SHAPED.UNIFIED_AI_USAGE
    GROUP BY PLATFORM_KEY
)
SELECT
    r.PLATFORM_KEY,
    r.DISPLAY_NAME,
    r.IS_ACTIVE,
    r.COST_MODEL,
    r.SUPPORTS_USER_GRAIN,
    r.SUPPORTS_USER_COST,
    s.LAST_SUCCESS_AT,
    s.STALEST_REPORT,
    f.LATEST_USAGE_DATE,
    r.EXPECTED_LAG_HOURS,
    DATEDIFF('hour', s.LAST_SUCCESS_AT, CURRENT_TIMESTAMP()) AS HOURS_SINCE_SUCCESS,
    COALESCE(rr.RUNS_7D, 0)         AS RUNS_7D,
    COALESCE(rr.FAILURES_7D, 0)     AS FAILURES_7D,
    COALESCE(rr.ROWS_LOADED_7D, 0)  AS ROWS_LOADED_7D,
    rr.LATEST_ERROR_CLASS,
    COALESCE(us.UNSHREDDABLE_ROWS, 0) AS UNSHREDDABLE_ROWS,
    COALESCE(f.FACT_ROWS, 0)        AS FACT_ROWS,
    COALESCE(f.DISTINCT_PEOPLE, 0)  AS DISTINCT_PEOPLE,
    f.UNRESOLVED_PCT,
    /* Ordered so the most alarming condition wins. NEVER_PULLED sits above STALE
       because "we activated this and it has never worked" is a different problem
       from "it worked and stopped". SHAPE_DRIFT sits high because it is the failure
       that produces a plausible wrong chart rather than an obvious gap. */
    CASE
        WHEN NOT r.IS_ACTIVE                            THEN 'INACTIVE'
        WHEN s.LAST_SUCCESS_AT IS NULL                  THEN 'NEVER_PULLED'
        WHEN COALESCE(us.UNSHREDDABLE_ROWS, 0) > 0      THEN 'SHAPE_DRIFT'
        WHEN DATEDIFF('hour', s.LAST_SUCCESS_AT, CURRENT_TIMESTAMP())
             > r.EXPECTED_LAG_HOURS                     THEN 'STALE'
        WHEN COALESCE(rr.FAILURES_7D, 0) > 0            THEN 'DEGRADED'
        /* Succeeding but landing nothing. The signature of an auth scope change or
           a silently emptied report -- looks healthy in the log, delivers no data. */
        WHEN COALESCE(rr.ROWS_LOADED_7D, 0) = 0
             AND COALESCE(rr.RUNS_7D, 0) > 0            THEN 'NO_DATA_RETURNED'
        WHEN COALESCE(f.UNRESOLVED_PCT, 0) > 25         THEN 'IDENTITY_GAP'
        ELSE 'HEALTHY'
    END                             AS HEALTH_STATUS,
    CASE
        WHEN NOT r.IS_ACTIVE
            THEN 'Not activated. Expected if this platform is not in scope yet.'
        WHEN s.LAST_SUCCESS_AT IS NULL
            THEN 'Activated but never pulled successfully. Check credential, network rule, and EAI secret allowlist.'
        WHEN COALESCE(us.UNSHREDDABLE_ROWS, 0) > 0
            THEN 'Rows landed but could not be shredded -- the vendor date or subject field did not parse. Almost always a renamed field. Fix the shredding view in sql/06 before trusting any chart.'
        WHEN DATEDIFF('hour', s.LAST_SUCCESS_AT, CURRENT_TIMESTAMP()) > r.EXPECTED_LAG_HOURS
            THEN 'Oldest report for this platform (' || COALESCE(s.STALEST_REPORT, 'unknown')
                 || ') is past its expected lag. Check the task is resumed and inspect the latest error class.'
        WHEN COALESCE(rr.FAILURES_7D, 0) > 0
            THEN 'Some pulls failed in the last 7 days. A SCHEMA_DRIFT error class means the vendor changed a field name.'
        WHEN COALESCE(rr.ROWS_LOADED_7D, 0) = 0 AND COALESCE(rr.RUNS_7D, 0) > 0
            THEN 'Pulls succeed but land no rows. Usually an auth scope change or a report that now returns empty. Investigate before trusting any chart.'
        WHEN COALESCE(f.UNRESOLVED_PCT, 0) > 25
            THEN 'Over a quarter of rows cannot be resolved to a person. Department allocation is unreliable until IDENTITY_MAP is seeded.'
        ELSE 'Fresh, succeeding, and resolving identities.'
    END                             AS RECOMMENDED_ACTION
FROM AI_SPEND.CONTROL.PLATFORM_REGISTRY r
LEFT JOIN last_success s ON s.PLATFORM_KEY = r.PLATFORM_KEY
LEFT JOIN recent_runs rr ON rr.PLATFORM_KEY = r.PLATFORM_KEY
LEFT JOIN fact_state f   ON f.PLATFORM_KEY = r.PLATFORM_KEY
LEFT JOIN unshreddable us ON us.PLATFORM_KEY = r.PLATFORM_KEY
ORDER BY
    CASE
        WHEN NOT r.IS_ACTIVE THEN 9
        WHEN s.LAST_SUCCESS_AT IS NULL THEN 1
        WHEN DATEDIFF('hour', s.LAST_SUCCESS_AT, CURRENT_TIMESTAMP()) > r.EXPECTED_LAG_HOURS THEN 2
        WHEN COALESCE(rr.FAILURES_7D, 0) > 0 THEN 3
        ELSE 5
    END,
    r.PLATFORM_KEY;

-- ---------------------------------------------------------------------------
-- The morning check
-- ---------------------------------------------------------------------------

SELECT
    PLATFORM_KEY,
    HEALTH_STATUS,
    HOURS_SINCE_SUCCESS,
    STALEST_REPORT,
    LATEST_USAGE_DATE,
    FAILURES_7D,
    UNSHREDDABLE_ROWS,
    UNRESOLVED_PCT,
    RECOMMENDED_ACTION
FROM AI_SPEND.CONTROL.V_PIPELINE_HEALTH
WHERE HEALTH_STATUS <> 'HEALTHY';

-- ---------------------------------------------------------------------------
-- 1. Adapter drift, grouped by error class
--
-- This is why ERROR_CLASS is stored as a separate column rather than left inside
-- the message. A GROUP BY here separates a credential problem from a rate limit
-- from a vendor schema change in one glance.
--
-- SCHEMA_DRIFT and RuntimeError rows are the ones to read first: they mean a
-- required field disappeared, which is the failure that would otherwise have
-- become a wrong chart.
-- ---------------------------------------------------------------------------

SELECT
    PLATFORM_KEY,
    REPORT_NAME,
    ERROR_CLASS,
    COUNT(*)                AS occurrences,
    MAX(STARTED_AT)         AS most_recent,
    MAX(ERROR_MESSAGE)      AS sample_message
FROM AI_SPEND.CONTROL.PULL_RUN_LOG
WHERE STATUS = 'FAILED'
  AND STARTED_AT >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY PLATFORM_KEY, REPORT_NAME, ERROR_CLASS
ORDER BY most_recent DESC;

-- ---------------------------------------------------------------------------
-- 2. Identity gaps, worst subjects first
--
-- The actionable output: the specific subject keys to add to IDENTITY_MAP, ordered
-- by how much unattributable spend each one is carrying. Work down this list and
-- the unattributed percentage falls fastest per unit of effort.
-- ---------------------------------------------------------------------------

SELECT
    PLATFORM_KEY,
    SUBJECT_KEY,
    MAX(SUBJECT_DISPLAY_NAME)           AS subject_display_name,
    COUNT(*)                            AS unresolved_rows,
    ROUND(SUM(COALESCE(COST_AMOUNT, 0)), 4) AS unattributed_cost,
    MIN(USAGE_DATE)                     AS first_seen,
    MAX(USAGE_DATE)                     AS last_seen
FROM AI_SPEND.SHAPED.UNIFIED_AI_USAGE
WHERE IDENTITY_CONFIDENCE = 'NONE'
GROUP BY PLATFORM_KEY, SUBJECT_KEY
ORDER BY unattributed_cost DESC NULLS LAST, unresolved_rows DESC
LIMIT 50;

-- Identity confidence mix. A high HEURISTIC share means the allocation rests on
-- guesses -- fine to ship, not fine to leave unsaid when presenting it.
SELECT * FROM AI_SPEND.SHAPED.V_IDENTITY_QUALITY;

-- ---------------------------------------------------------------------------
-- 3. Dynamic Table refresh health
--
-- A Dynamic Table that silently stops refreshing produces stale numbers with no
-- error anywhere in the run log, because the run log only knows about API pulls.
-- ---------------------------------------------------------------------------

SELECT
    NAME,
    SCHEMA_NAME,
    STATE,
    STATE_MESSAGE,
    REFRESH_START_TIME,
    REFRESH_END_TIME,
    DATEDIFF('minute', REFRESH_END_TIME, CURRENT_TIMESTAMP()) AS minutes_since_refresh
FROM TABLE(AI_SPEND.INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE REFRESH_START_TIME >= DATEADD('day', -2, CURRENT_TIMESTAMP())
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY SCHEMA_NAME, NAME ORDER BY REFRESH_START_TIME DESC
) = 1
ORDER BY STATE, NAME;

-- Task history for the adapter pulls.
SELECT
    NAME,
    SCHEDULED_TIME,
    STATE,
    ERROR_CODE,
    ERROR_MESSAGE
FROM TABLE(AI_SPEND.INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC
LIMIT 50;

-- ---------------------------------------------------------------------------
-- 4. This pipeline's own Snowflake cost
--
-- A cost-visibility pipeline that cannot report its own cost is not a good look,
-- and it is also the number someone will eventually ask for. The QUERY_TAG set by
-- every adapter is what makes this possible.
--
-- ACCOUNT_USAGE latency varies by view (commonly ~45 minutes to 3 hours, some
-- views up to 24 hours), so today will look understated by a different amount
-- per source. Check the specific view before treating a gap as a real shortfall.
-- ---------------------------------------------------------------------------

SELECT
    TO_DATE(START_TIME)                             AS usage_date,
    SPLIT_PART(QUERY_TAG, ':', 2)                   AS platform_key,
    COUNT(*)                                        AS query_count,
    ROUND(SUM(TOTAL_ELAPSED_TIME) / 1000 / 60, 2)   AS total_minutes,
    ROUND(SUM(CREDITS_USED_CLOUD_SERVICES), 6)      AS cloud_services_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TAG LIKE 'AI_SPEND:%'
  AND START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY usage_date, platform_key
ORDER BY usage_date DESC, total_minutes DESC;

/* Warehouse credits for this pipeline. QUERY_HISTORY has no warehouse credit
   column -- only cloud services -- so warehouse compute must come from
   WAREHOUSE_METERING_HISTORY. Attributable because this pipeline has its own
   dedicated warehouse, which is the reason to give it one. */
SELECT
    TO_DATE(START_TIME)                 AS usage_date,
    ROUND(SUM(CREDITS_USED_COMPUTE), 6) AS compute_credits,
    ROUND(SUM(CREDITS_USED), 6)         AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE WAREHOUSE_NAME = 'AI_SPEND_WH'
  AND START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY usage_date
ORDER BY usage_date DESC;

-- ---------------------------------------------------------------------------
-- Optional: alert on unhealthy platforms
--
-- Requires a notification integration. Left commented because creating one is a
-- separate decision with its own approvals.
--
-- Note the condition covers STALE and NEVER_PULLED, not just failures. A pipeline
-- that stops running quietly will never raise an error-based alert.
-- ---------------------------------------------------------------------------

/*
CREATE OR REPLACE ALERT AI_SPEND.CONTROL.ALERT_PIPELINE_UNHEALTHY
  WAREHOUSE = AI_SPEND_WH
  SCHEDULE = 'USING CRON 0 9 * * * UTC'
  IF (EXISTS (
    SELECT 1 FROM AI_SPEND.CONTROL.V_PIPELINE_HEALTH
    WHERE HEALTH_STATUS IN ('STALE', 'NEVER_PULLED', 'DEGRADED',
                            'NO_DATA_RETURNED', 'SHAPE_DRIFT')
  ))
  THEN CALL SYSTEM$SEND_EMAIL(
    '<notification_integration_name>',
    '<owner@example.com>',
    'AI spend pipeline needs attention',
    'One or more AI platforms are stale, failing, or returning no data. '
      || 'Check AI_SPEND.CONTROL.V_PIPELINE_HEALTH.'
  );

ALTER ALERT AI_SPEND.CONTROL.ALERT_PIPELINE_UNHEALTHY RESUME;
*/
