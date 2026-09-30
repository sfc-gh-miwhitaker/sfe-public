/*
  Snowflake ML Lifecycle — cost drivers for deployed models (read-only)
  Pair-programmed by SE Community + Cortex Code

  Requires: IMPORTED PRIVILEGES on database SNOWFLAKE (ACCOUNT_USAGE).
  All figures are CREDITS. Convert with your contract rate, not a list price.
  Substitute: ML_CPU_POOL (compute pool name). Everything else runs as-is.
*/

-- 1. Compute pool credits by pool and day (real-time serving, ML Jobs, batch run_batch)
--    Pools bill while any node is up, including idle time before AUTO_SUSPEND_SECS.
SELECT
    compute_pool_name,
    DATE_TRUNC('day', start_time) AS usage_day,
    SUM(credits_used)             AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWPARK_CONTAINER_SERVICES_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY compute_pool_name, usage_day
ORDER BY usage_day DESC, credits DESC;

-- 2. Model serving credits (warehouse and SPCS inference) as Snowflake attributes them.
--    The SPCS share is an ATTRIBUTION of query 1's pool credits — never add 1 and 2 together.
--    This view can lag up to 24 hours.
SELECT
    DATE_TRUNC('day', start_time) AS usage_day,
    SUM(credits)                  AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.MODEL_SERVING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY usage_day
ORDER BY usage_day DESC;

-- 3. Idle-hour check: pool hours that billed outside 08:00-18:59 in YOUR time zone.
--    Set the time zone below. A nonzero count overnight usually means MIN_NODES or
--    AUTO_SUSPEND_SECS is keeping a node up.
SELECT
    compute_pool_name,
    COUNT(*)          AS billed_hours,
    SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWPARK_CONTAINER_SERVICES_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND compute_pool_name = 'ML_CPU_POOL'
  AND HOUR(CONVERT_TIMEZONE('America/Chicago', start_time)) NOT BETWEEN 8 AND 18
GROUP BY compute_pool_name;

-- 4. Warehouse credits for batch inference, monitor refresh, and feature view refresh.
--    Isolate ML work on its own warehouse (ML_WH) so this number means something.
SELECT
    warehouse_name,
    DATE_TRUNC('day', start_time) AS usage_day,
    SUM(credits_used_compute)     AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_services_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name, usage_day
ORDER BY usage_day DESC, compute_credits DESC;

-- 5. Per-query attribution on a shared warehouse, split by QUERY_TAG
--    (set ALTER SESSION SET QUERY_TAG = 'ml:batch_inference' etc. in your pipelines).
SELECT
    query_tag,
    warehouse_name,
    SUM(credits_attributed_compute) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND query_tag LIKE 'ml:%'
GROUP BY query_tag, warehouse_name
ORDER BY credits DESC;

-- 6. Notebook (Container Runtime) credits by user — interactive training and exploration
SELECT
    user_name,
    SUM(credits) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.NOTEBOOKS_CONTAINER_RUNTIME_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY user_name
ORDER BY credits DESC;

-- 7. Storage for the ML database (feature view tables, datasets, model artifacts, monitor logs)
SELECT
    database_name,
    usage_date,
    average_database_bytes / POWER(1024, 3) AS database_gib,
    average_failsafe_bytes / POWER(1024, 3) AS failsafe_gib
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
  AND database_name = 'ML_DB'
ORDER BY usage_date DESC;
