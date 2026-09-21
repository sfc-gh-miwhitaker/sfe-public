/*
  guide-shopify-multistore-snowflake — sql/openflow/07_monitoring.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    Openflow-specific monitoring. Path-neutral monitoring (freshness, registry
    hygiene, contract conformance, reconciliation) lives in
    sql/shared/03_monitoring.sql and is the same on both paths. This file covers
    what only exists on the Openflow path:
      A. What is Openflow costing, and how much is the always-on floor?
      B. Runtime errors, classified against documented failure signatures
      C. Ingestion warehouse MERGE volume
      D. Dynamic Table refresh health
      E. Connector-to-registry mismatch (wrong store wired to a schema)

  RUN AS      OPENFLOW_ADMIN (needs SNOWFLAKE.ACCOUNT_USAGE access via
              GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE, or ACCOUNTADMIN)
  LATENCY     ACCOUNT_USAGE views lag up to ~3 hours (METERING_*) / 45 min (QUERY_HISTORY)
  SOURCE      https://docs.snowflake.com/en/user-guide/data-integration/openflow/cost-spcs
*/

-- A1. Openflow compute credits by compute pool, last 30 days ------------------
--     SERVICE_TYPE = OPENFLOW_COMPUTE_SNOWFLAKE; NAME is the compute pool.
--     The pool named like OPENFLOW_CONTROL_POOL% is the Management Services
--     floor. It bills whether or not any runtime is running, and only
--     DROP OPENFLOW DEPLOYMENT stops it.
SELECT
  DATE_TRUNC('day', START_TIME)                          AS USAGE_DAY,
  NAME                                                   AS COMPUTE_POOL,
  CASE WHEN NAME ILIKE 'OPENFLOW_CONTROL_POOL%' THEN 'management floor'
       ELSE 'runtime' END                                AS POOL_KIND,
  SUM(CREDITS_USED)                                      AS CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
WHERE SERVICE_TYPE = 'OPENFLOW_COMPUTE_SNOWFLAKE'
  AND START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY USAGE_DAY, COMPUTE_POOL, POOL_KIND
ORDER BY USAGE_DAY DESC, CREDITS DESC;

-- A2. Full cost picture: Openflow compute + Snowpipe Streaming + warehouses ---
--     Per-runtime attribution is NOT available for Snowflake deployments
--     (OPENFLOW_USAGE_HISTORY covers BYOC only), and there is no per-store
--     attribution at all on this path. This is the closest you get: put each
--     store on its own runtime, or accept an allocation.
--     METERING_HISTORY (hourly) is used because it carries NAME, which
--     METERING_DAILY_HISTORY does not.
SELECT
  DATE_TRUNC('week', START_TIME)                         AS USAGE_WEEK,
  SERVICE_TYPE,
  SUM(CREDITS_USED)                                      AS CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
WHERE START_TIME >= DATEADD('day', -90, CURRENT_TIMESTAMP())
  AND (SERVICE_TYPE IN ('OPENFLOW_COMPUTE_SNOWFLAKE', 'SNOWPIPE_STREAMING')
       OR (SERVICE_TYPE = 'WAREHOUSE_METERING'
           AND NAME IN ('SHOPIFY_INGEST_WH', 'SHOPIFY_ANALYTICS_WH')))
GROUP BY USAGE_WEEK, SERVICE_TYPE
ORDER BY USAGE_WEEK DESC, CREDITS DESC;

-- B1. Runtime errors from the dedicated event table, last 24 hours ------------
--     Column names (TIMESTAMP, RECORD_TYPE, RECORD, RESOURCE_ATTRIBUTES, VALUE)
--     are the standard Snowflake event table schema. The exact resource
--     attribute key that carries the runtime name is not documented for
--     Openflow; run
--       SELECT DISTINCT RESOURCE_ATTRIBUTES FROM OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_EVENTS LIMIT 20;
--     once and adjust the key below.
SELECT
  TIMESTAMP,
  RESOURCE_ATTRIBUTES:"openflow.runtime.name"::VARCHAR   AS RUNTIME_NAME,
  RECORD:severity_text::VARCHAR                          AS SEVERITY,
  LEFT(VALUE::VARCHAR, 500)                              AS MESSAGE
FROM OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_EVENTS
WHERE RECORD_TYPE = 'LOG'
  AND TIMESTAMP >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
  AND RECORD:severity_text::VARCHAR IN ('ERROR', 'WARN')
ORDER BY TIMESTAMP DESC
LIMIT 200;

-- B2. Known-error classifier --------------------------------------------------
--     Maps documented failure signatures to the fix, so the on-call person does
--     not have to remember the troubleshooting page.
SELECT
  TIMESTAMP,
  CASE
    WHEN VALUE::VARCHAR ILIKE '%UnknownHostException%myshopify.com%'
      THEN 'EAI missing or not granted to execute-as role (03_execute_as_role_eai.sql)'
    WHEN VALUE::VARCHAR ILIKE '%UnresolvedAddressException%' OR VALUE::VARCHAR ILIKE '%storage.googleapis.com%'
      THEN 'Network rule missing storage.googleapis.com:443'
    WHEN VALUE::VARCHAR ILIKE '%401%' OR VALUE::VARCHAR ILIKE '%Invalid API key or access token%'
      THEN 'Shopify app uninstalled, unreleased, or wrong Client ID/Secret'
    WHEN VALUE::VARCHAR ILIKE '%ACCESS_DENIED%' OR VALUE::VARCHAR ILIKE '%Access denied for%'
      THEN 'Missing read_* scope or protected-customer-data approval; release new app version and reinstall'
    WHEN VALUE::VARCHAR ILIKE '%not approved to access%'
      THEN 'Protected customer data; submit a Shopify access request for this app'
    WHEN VALUE::VARCHAR ILIKE '%Invalid search field%'
      THEN 'incrementalField not filterable; set supportsIncremental=false, refreshStrategy=FULL_PERIODIC'
    WHEN VALUE::VARCHAR ILIKE '%first cannot exceed 250%'
      THEN 'pageSize > 250 in override JSON'
    WHEN VALUE::VARCHAR ILIKE '%Must be a JSON array%' OR VALUE::VARCHAR ILIKE '%Invalid JSON%'
      THEN 'Object Definitions Override is not a valid JSON array'
    WHEN VALUE::VARCHAR ILIKE '%bulk operation%already%'
      -- On API version 2026-01 and higher each APP gets five concurrent bulk
      -- query operations per shop (earlier versions: one of each type). The
      -- limit is per app, so another vendor's integration on the same store
      -- does NOT consume your slots. List your own in-flight operations with
      -- the bulkOperations query before assuming contention.
      THEN 'Your app has all its concurrent bulk query slots in flight for this shop; list bulkOperations, then back off and retry'
    ELSE 'UNCLASSIFIED - read the message'
  END AS LIKELY_CAUSE,
  LEFT(VALUE::VARCHAR, 300) AS MESSAGE
FROM OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_EVENTS
WHERE RECORD_TYPE = 'LOG'
  AND TIMESTAMP >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
  AND RECORD:severity_text::VARCHAR = 'ERROR'
QUALIFY ROW_NUMBER() OVER (PARTITION BY LIKELY_CAUSE ORDER BY TIMESTAMP DESC) <= 3
ORDER BY LIKELY_CAUSE, TIMESTAMP DESC;

-- C. Ingestion warehouse: MERGE volume per day --------------------------------
--    A daily sync across N stores should produce roughly N x (objects) MERGEs.
--    A jump here usually means a state reset re-ran a bulk load.
SELECT
  DATE_TRUNC('day', START_TIME)                          AS RUN_DAY,
  QUERY_TYPE,
  COUNT(*)                                               AS STATEMENTS,
  ROUND(SUM(TOTAL_ELAPSED_TIME) / 1000 / 60, 1)          AS MINUTES_ELAPSED
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE WAREHOUSE_NAME = 'SHOPIFY_INGEST_WH'
  AND START_TIME >= DATEADD('day', -14, CURRENT_TIMESTAMP())
  AND QUERY_TYPE IN ('MERGE', 'CREATE_TABLE', 'INSERT')
GROUP BY RUN_DAY, QUERY_TYPE
ORDER BY RUN_DAY DESC, STATEMENTS DESC;

-- D. Dynamic Table refresh health ---------------------------------------------
SELECT
  NAME,
  STATE,
  STATE_CODE,
  REFRESH_START_TIME,
  REFRESH_END_TIME,
  DATEDIFF('second', REFRESH_START_TIME, REFRESH_END_TIME) AS REFRESH_SECONDS
FROM TABLE(SHOPIFY_ANALYTICS.INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
  DATA_TIMESTAMP_START => DATEADD('day', -7, CURRENT_TIMESTAMP())))
WHERE STATE <> 'SUCCEEDED'
ORDER BY REFRESH_START_TIME DESC;

-- E. Connector-to-registry mismatch -------------------------------------------
--    Catches the most expensive canvas typo: a connector parameterized with the
--    wrong Shop Domain for the destination schema it writes to. The connector's
--    own SHOP_URL column is compared with the registry domain for that
--    STORE_KEY. Any row returned means a store's data is landing in another
--    store's schema.
SELECT
  O.STORE_KEY,
  R.SHOP_DOMAIN                AS REGISTRY_DOMAIN,
  O.SHOP_URL                   AS CONNECTOR_SHOP_URL,
  COUNT(*)                     AS AFFECTED_ORDERS
FROM SHOPIFY_ANALYTICS.CORE.ORDERS_ALL O
JOIN SHOPIFY_CONTROL.META.STORE_REGISTRY R
  ON R.STORE_KEY = O.STORE_KEY
WHERE O.SHOP_URL IS NOT NULL
  AND LOWER(O.SHOP_URL) <> LOWER(R.SHOP_DOMAIN)
GROUP BY O.STORE_KEY, R.SHOP_DOMAIN, O.SHOP_URL
ORDER BY AFFECTED_ORDERS DESC;
