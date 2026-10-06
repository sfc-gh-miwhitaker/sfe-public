/*
  guide-shopify-multistore-snowflake — sql/native/06_monitoring.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    Native-path monitoring: the evidence CoCo Desktop and the read-only
    automations read. Path-neutral monitoring (freshness, registry hygiene,
    contract conformance, cutover reconciliation) lives in
    sql/shared/03_monitoring.sql and is identical on both paths.

  RUN AS      SHOPIFY_PIPELINE_RL (ACCOUNT_USAGE queries need
              GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE)
*/

USE ROLE SHOPIFY_PIPELINE_RL;

-- A. Pipeline health: last run per store per object -----------------------------
CREATE OR REPLACE VIEW SHOPIFY_NATIVE.CONTROL.V_PIPELINE_HEALTH
COMMENT = 'Last pull attempt per store and object, joined to the shared registry'
AS
WITH LAST_RUN AS (
  SELECT STORE_KEY, OBJECT_NAME, STATUS, COMPLETED_AT, ROWS_LOADED,
         ERROR_CLASS, ERROR_MESSAGE, BULK_OPERATION_ID
  FROM SHOPIFY_NATIVE.CONTROL.PULL_RUN_LOG
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY STORE_KEY, OBJECT_NAME ORDER BY STARTED_AT DESC
  ) = 1
)
SELECT
  R.STORE_KEY,
  R.SHOP_DOMAIN,
  R.IS_ACTIVE,
  R.QUALIFICATION_STATUS,
  L.OBJECT_NAME,
  L.STATUS                                              AS LAST_RUN_STATUS,
  L.COMPLETED_AT                                        AS LAST_COMPLETED_AT,
  DATEDIFF('hour', L.COMPLETED_AT, CURRENT_TIMESTAMP()) AS HOURS_SINCE_COMPLETION,
  L.ROWS_LOADED,
  L.BULK_OPERATION_ID,
  L.ERROR_CLASS,
  L.ERROR_MESSAGE
FROM SHOPIFY_CONTROL.META.STORE_REGISTRY R
LEFT JOIN LAST_RUN L ON L.STORE_KEY = R.STORE_KEY;

SELECT STORE_KEY, SHOP_DOMAIN, OBJECT_NAME, LAST_RUN_STATUS, LAST_COMPLETED_AT,
       HOURS_SINCE_COMPLETION, ROWS_LOADED, ERROR_CLASS
FROM SHOPIFY_NATIVE.CONTROL.V_PIPELINE_HEALTH
ORDER BY STORE_KEY, OBJECT_NAME;

-- B. Zero-lag task history (last 7 days) ---------------------------------------
--    Filters are pushed into the table function, not applied afterwards.
SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, QUERY_ID, ERROR_CODE, ERROR_MESSAGE
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.TASK_HISTORY(
  TASK_NAME => 'DAILY_SHOPIFY_PULL',
  SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
  SCHEDULED_TIME_RANGE_END => CURRENT_TIMESTAMP(),
  RESULT_LIMIT => 10000
))
WHERE DATABASE_NAME = 'SHOPIFY_NATIVE' AND SCHEMA_NAME = 'CONTROL'
ORDER BY SCHEDULED_TIME DESC;

-- C. Dynamic Table refresh errors ----------------------------------------------
USE DATABASE SHOPIFY_NATIVE;
SELECT NAME, STATE, STATE_MESSAGE, REFRESH_ACTION, REFRESH_START_TIME, REFRESH_END_TIME
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
  NAME_PREFIX => 'SHOPIFY_NATIVE.ANALYTICS',
  ERROR_ONLY => TRUE,
  DATA_TIMESTAMP_START => DATEADD('day', -30, CURRENT_TIMESTAMP())
))
ORDER BY REFRESH_START_TIME DESC;

-- D. Per-store cost attribution ------------------------------------------------
--    This is the native path's structural advantage over Openflow: the pull
--    procedure sets a per-store QUERY_TAG, so credits attribute per store.
--    Openflow Snowflake Deployments have no per-runtime attribution at all.
SELECT
  REGEXP_SUBSTR(QUERY_TAG, 'SHOPIFY_NATIVE:([^:]+)', 1, 1, 'e', 1) AS STORE_KEY,
  DATE_TRUNC('week', START_TIME)                                   AS USAGE_WEEK,
  SUM(CREDITS_ATTRIBUTED_COMPUTE)                                  AS CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
WHERE START_TIME >= DATEADD('day', -90, CURRENT_TIMESTAMP())
  AND QUERY_TAG LIKE 'SHOPIFY_NATIVE:%'
GROUP BY STORE_KEY, USAGE_WEEK
ORDER BY USAGE_WEEK DESC, CREDITS DESC;

-- E. Qualification evidence ----------------------------------------------------
--    Read this before activating a store or resuming the task.
SELECT STORE_KEY, GATE_NAME, PASSED, EVIDENCE, CHECKED_AT
FROM SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS
ORDER BY STORE_KEY, CHECKED_AT, GATE_NAME;

-- F. Stage inventory for retention review --------------------------------------
--    The stage grows without bound. Deletion is an explicit decision; weekly
--    supervision only reports.
ALTER STAGE SHOPIFY_NATIVE.LANDING.SHOPIFY_STAGE REFRESH;
SELECT RELATIVE_PATH, SIZE, LAST_MODIFIED
FROM DIRECTORY(@SHOPIFY_NATIVE.LANDING.SHOPIFY_STAGE)
ORDER BY LAST_MODIFIED DESC;

-- G. Failure classifier --------------------------------------------------------
--    Maps the run log's error text to the first failing boundary, so the
--    troubleshooting playbook starts from evidence rather than a guess.
SELECT
  STORE_KEY,
  OBJECT_NAME,
  STARTED_AT,
  ERROR_CLASS,
  CASE
    WHEN ERROR_MESSAGE ILIKE '%401%' OR ERROR_MESSAGE ILIKE '%access_token%'
      THEN 'Token request failed: app not installed/released, or wrong secret'
    WHEN ERROR_MESSAGE ILIKE '%SHOPIFY_VALIDATION%'
      THEN 'GraphQL rejected: unsupported field or missing read scope'
    WHEN ERROR_MESSAGE ILIKE '%SHOPIFY_BULK_%'
      -- On 2026-01 and later each app gets five concurrent bulk query
      -- operations per shop. The limit is per app, so another vendor's
      -- integration on the same store does not consume your slots.
      THEN 'Bulk operation did not COMPLETE: Shopify-side failure, timeout, or all five of this app slots in flight'
    WHEN ERROR_MESSAGE ILIKE '%UnknownHost%' OR ERROR_MESSAGE ILIKE '%Name or service not known%'
      THEN 'EAI or network rule does not allow this host'
    WHEN ERROR_MESSAGE ILIKE '%expired%'
      THEN 'Result URL expired: operations must be downloaded within seven days'
    WHEN ERROR_MESSAGE ILIKE '%COPY%' OR ERROR_MESSAGE ILIKE '%Error parsing JSON%'
      THEN 'COPY rejected the JSONL: file format or contract change'
    WHEN ERROR_MESSAGE ILIKE '%put_stream%' OR ERROR_MESSAGE ILIKE '%stage%'
      THEN 'Stage write failed: check stage privilege; do not substitute SQL PUT'
    ELSE 'UNCLASSIFIED - read ERROR_MESSAGE'
  END AS LIKELY_CAUSE,
  LEFT(ERROR_MESSAGE, 300) AS ERROR_EXCERPT
FROM SHOPIFY_NATIVE.CONTROL.PULL_RUN_LOG
WHERE STATUS = 'FAILED'
  AND STARTED_AT >= DATEADD('day', -7, CURRENT_TIMESTAMP())
QUALIFY ROW_NUMBER() OVER (PARTITION BY STORE_KEY, OBJECT_NAME ORDER BY STARTED_AT DESC) <= 3
ORDER BY STARTED_AT DESC;
