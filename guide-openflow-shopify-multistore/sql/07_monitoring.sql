/*
  guide-openflow-shopify-multistore — 07_monitoring.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-03

  PURPOSE
    The queries an admin runs every morning (or schedules as a task):
      A. What is Openflow costing, and how much of it is the always-on floor?
      B. Is every store landing data?
      C. What errors did the runtime log in the last 24 hours?
      D. Is the ingestion warehouse being used more than expected?

  RUN AS      OPENFLOW_ADMIN (needs SNOWFLAKE.ACCOUNT_USAGE access via
              GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE, or ACCOUNTADMIN)
  LATENCY     ACCOUNT_USAGE views lag up to ~3 hours (METERING_*) / 45 min (QUERY_HISTORY)
  SOURCE      https://docs.snowflake.com/en/user-guide/data-integration/openflow/cost-spcs
*/

-- A1. Openflow compute credits by compute pool, last 30 days -------------------
--     SERVICE_TYPE = OPENFLOW_COMPUTE_SNOWFLAKE; NAME is the compute pool.
--     The pool named like OPENFLOW_CONTROL_POOL_% is the Management Services
--     floor. It bills whether or not any runtime is running.
SELECT
  DATE_TRUNC('day', start_time)                          AS usage_day,
  name                                                   AS compute_pool,
  CASE WHEN name ILIKE 'OPENFLOW_CONTROL_POOL%' THEN 'management floor'
       ELSE 'runtime' END                                AS pool_kind,
  SUM(credits_used)                                      AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
WHERE service_type = 'OPENFLOW_COMPUTE_SNOWFLAKE'
  AND start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY usage_day, compute_pool, pool_kind
ORDER BY usage_day DESC, credits DESC;

-- A2. Full cost picture: Openflow compute + Snowpipe Streaming + warehouses -----
--     Per-runtime attribution is NOT available for Snowflake deployments
--     (OPENFLOW_USAGE_HISTORY covers BYOC only). This is the closest you get.
--     METERING_HISTORY (hourly) is used because it carries NAME, which
--     METERING_DAILY_HISTORY does not; NAME is needed to isolate the two
--     warehouses this guide creates.
SELECT
  DATE_TRUNC('week', start_time)                         AS usage_week,
  service_type,
  SUM(credits_used)                                      AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
  AND (service_type IN ('OPENFLOW_COMPUTE_SNOWFLAKE', 'SNOWPIPE_STREAMING')
       OR (service_type = 'WAREHOUSE_METERING'
           AND name IN ('SHOPIFY_INGEST_WH', 'SHOPIFY_ANALYTICS_WH')))
GROUP BY usage_week, service_type
ORDER BY usage_week DESC, credits DESC;

-- B. Per-store freshness (fails loudly: NULL = registered but never loaded) -----
SELECT
  store_key,
  shop_domain,
  business_owner,
  orders_loaded,
  last_order_update,
  hours_since_last_update,
  CASE
    WHEN orders_loaded = 0                    THEN 'NEVER LOADED - check connector installed and started'
    WHEN hours_since_last_update > 48         THEN 'STALE - check runtime bulletins and Shopify app status'
    WHEN hours_since_last_update > 30         THEN 'LATE - one daily sync missed'
    ELSE 'OK'
  END AS freshness_status
FROM SHOPIFY_ANALYTICS.CORE.STORE_FRESHNESS
ORDER BY orders_loaded = 0 DESC, hours_since_last_update DESC NULLS FIRST;

-- C. Runtime errors from the dedicated event table, last 24 hours --------------
--    Column names (TIMESTAMP, RECORD_TYPE, RECORD, RESOURCE_ATTRIBUTES, VALUE)
--    are the standard Snowflake event table schema. The exact resource
--    attribute key that carries the runtime name is not documented for
--    Openflow; run  SELECT DISTINCT resource_attributes FROM ... LIMIT 20
--    once and adjust the key below.
SELECT
  timestamp,
  resource_attributes:"openflow.runtime.name"::VARCHAR   AS runtime_name,
  record:severity_text::VARCHAR                          AS severity,
  LEFT(value::VARCHAR, 500)                              AS message
FROM OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_EVENTS
WHERE record_type = 'LOG'
  AND timestamp >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
  AND record:severity_text::VARCHAR IN ('ERROR', 'WARN')
ORDER BY timestamp DESC
LIMIT 200;

-- C2. Known-error classifier for the Shopify connector -------------------------
--     Maps the doc'd failure signatures to the fix, so the on-call person does
--     not have to remember the troubleshooting page.
SELECT
  timestamp,
  CASE
    WHEN value::VARCHAR ILIKE '%UnknownHostException%myshopify.com%'
      THEN 'EAI missing or not granted to execute-as role (03_execute_as_role_eai.sql)'
    WHEN value::VARCHAR ILIKE '%UnresolvedAddressException%' OR value::VARCHAR ILIKE '%storage.googleapis.com%'
      THEN 'Network rule missing storage.googleapis.com:443'
    WHEN value::VARCHAR ILIKE '%401%' OR value::VARCHAR ILIKE '%Invalid API key or access token%'
      THEN 'Shopify app uninstalled, unreleased, or wrong Client ID/Secret'
    WHEN value::VARCHAR ILIKE '%ACCESS_DENIED%' OR value::VARCHAR ILIKE '%Access denied for%'
      THEN 'Missing read_* scope or protected-customer-data approval; release new app version and reinstall'
    WHEN value::VARCHAR ILIKE '%Invalid search field%'
      THEN 'incrementalField not filterable; set supportsIncremental=false, refreshStrategy=FULL_PERIODIC'
    WHEN value::VARCHAR ILIKE '%first cannot exceed 250%'
      THEN 'pageSize > 250 in override JSON'
    WHEN value::VARCHAR ILIKE '%Must be a JSON array%' OR value::VARCHAR ILIKE '%Invalid JSON%'
      THEN 'Object Definitions Override is not valid JSON array'
    WHEN value::VARCHAR ILIKE '%bulk operation%already%'
      THEN 'Another bulk op in flight on this shop (only one per shop at a time)'
    ELSE 'UNCLASSIFIED - read the message'
  END AS likely_cause,
  LEFT(value::VARCHAR, 300) AS message
FROM OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_EVENTS
WHERE record_type = 'LOG'
  AND timestamp >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
  AND record:severity_text::VARCHAR = 'ERROR'
QUALIFY ROW_NUMBER() OVER (PARTITION BY likely_cause ORDER BY timestamp DESC) <= 3
ORDER BY likely_cause, timestamp DESC;

-- D. Ingestion warehouse: MERGE volume per day ---------------------------------
--    A daily sync across N stores should produce roughly N x (objects) MERGEs.
--    A jump here usually means a state reset re-ran a bulk load.
SELECT
  DATE_TRUNC('day', start_time)                          AS run_day,
  query_type,
  COUNT(*)                                               AS statements,
  ROUND(SUM(total_elapsed_time) / 1000 / 60, 1)          AS minutes_elapsed
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE warehouse_name = 'SHOPIFY_INGEST_WH'
  AND start_time >= DATEADD('day', -14, CURRENT_TIMESTAMP())
  AND query_type IN ('MERGE', 'CREATE_TABLE', 'INSERT')
GROUP BY run_day, query_type
ORDER BY run_day DESC, statements DESC;

-- E. Dynamic Table refresh health ---------------------------------------------
SELECT
  name,
  state,
  state_code,
  refresh_start_time,
  refresh_end_time,
  DATEDIFF('second', refresh_start_time, refresh_end_time) AS refresh_seconds
FROM TABLE(SHOPIFY_ANALYTICS.INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
  DATA_TIMESTAMP_START => DATEADD('day', -7, CURRENT_TIMESTAMP())))
WHERE state <> 'SUCCEEDED'
ORDER BY refresh_start_time DESC;
