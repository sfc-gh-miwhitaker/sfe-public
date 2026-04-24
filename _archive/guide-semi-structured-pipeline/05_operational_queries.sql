/*==============================================================================
OPERATIONAL QUERIES
Semi-Structured Data Pipeline Architecture Guide

Queries for monitoring, debugging, and governing the pipeline in production.

Prerequisite: Run 01-03 workbooks first.

Docs:
  - DT Refresh History:  https://docs.snowflake.com/en/sql-reference/functions/dynamic_table_refresh_history
  - Monitor DT Perf:     https://docs.snowflake.com/en/user-guide/dynamic-tables-performance-monitor
  - Data Quality:        https://docs.snowflake.com/en/user-guide/data-quality-intro
  - System DMFs:         https://docs.snowflake.com/en/user-guide/data-quality-system-dmfs
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA SEMI_STRUCTURED_PIPELINE;
USE WAREHOUSE SFE_PIPELINE_WH;

-- ============================================================================
-- DT REFRESH MONITORING
-- ============================================================================

-- All recent refreshes for silver_events
SELECT
    name,
    state,
    state_message,
    refresh_trigger,
    refresh_action,
    refresh_start_time,
    refresh_end_time,
    DATEDIFF('second', refresh_start_time, refresh_end_time) AS duration_seconds
FROM TABLE(
    INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
        NAME => 'SILVER_EVENTS'
    )
)
ORDER BY refresh_end_time DESC
LIMIT 20;

-- Failed refreshes only (quick health check)
SELECT
    name,
    state,
    state_message,
    refresh_end_time
FROM TABLE(
    INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
        NAME => 'SILVER_EVENTS',
        ERROR_ONLY => TRUE
    )
)
ORDER BY refresh_end_time DESC
LIMIT 10;

-- ============================================================================
-- CAST FAILURE INVESTIGATION
-- Find rows where TRY_CAST returned NULL but the raw value exists.
-- These are the rows that would silently vanish with bare :: casts.
-- ============================================================================

SELECT
    event_id_raw,
    event_ts_raw,
    customer_id_raw,
    source_file,
    file_row_number,
    load_ts
FROM silver_events
WHERE (event_id IS NULL AND event_id_raw IS NOT NULL)
   OR (event_ts IS NULL AND event_ts_raw IS NOT NULL)
   OR (customer_id IS NULL AND customer_id_raw IS NOT NULL)
ORDER BY load_ts DESC;

-- Cast failure summary by column
SELECT
    'event_id' AS column_name,
    COUNT_IF(event_id IS NULL AND event_id_raw IS NOT NULL) AS cast_failures,
    COUNT(*) AS total_rows
FROM silver_events
UNION ALL
SELECT
    'event_ts',
    COUNT_IF(event_ts IS NULL AND event_ts_raw IS NOT NULL),
    COUNT(*)
FROM silver_events
UNION ALL
SELECT
    'customer_id',
    COUNT_IF(customer_id IS NULL AND customer_id_raw IS NOT NULL),
    COUNT(*)
FROM silver_events;

-- ============================================================================
-- DATA METRIC FUNCTIONS (requires Enterprise Edition)
-- Attach system DMFs to gold tables for continuous quality monitoring.
-- ============================================================================

-- Set schedule: run DMFs when the table changes
ALTER TABLE gold_daily_sales
    SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- NULL_COUNT on required columns (NULLs in gold = upstream failure)
ALTER TABLE gold_daily_sales ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (sale_date);

ALTER TABLE gold_daily_sales ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (total_revenue);

-- ROW_COUNT to detect volume drift
ALTER TABLE gold_daily_sales ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.ROW_COUNT ON ();

-- FRESHNESS on silver to catch stale Dynamic Tables
ALTER DYNAMIC TABLE silver_events
    SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

ALTER DYNAMIC TABLE silver_events ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.FRESHNESS ON (load_ts);

-- ============================================================================
-- VIEW DMF RESULTS
-- Results populate ~10 minutes after first schedule activation.
-- Your role needs SNOWFLAKE.DATA_QUALITY_MONITORING_VIEWER application role.
-- ============================================================================

SELECT
    measurement_time,
    metric_name,
    table_name,
    table_schema,
    arguments_names,
    value
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_schema = 'SEMI_STRUCTURED_PIPELINE'
ORDER BY measurement_time DESC
LIMIT 20;

-- Detect violations: NULL_COUNT > 0 on a required column
SELECT
    measurement_time,
    metric_name,
    table_name,
    arguments_names,
    value
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_schema = 'SEMI_STRUCTURED_PIPELINE'
  AND metric_name = 'NULL_COUNT'
  AND value > 0
ORDER BY measurement_time DESC;

-- ============================================================================
-- DMF COST TRACKING
-- DMFs run on serverless compute. Monitor credits consumed.
-- ============================================================================

-- Requires ACCOUNTADMIN or USAGE on SNOWFLAKE.ACCOUNT_USAGE
-- SELECT
--     start_time::DATE AS day,
--     SUM(credits_used) AS dmf_credits
-- FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_USAGE_HISTORY
-- GROUP BY day
-- ORDER BY day DESC;

-- ============================================================================
-- PIPELINE HEALTH DASHBOARD (all-in-one)
-- ============================================================================

SELECT
    'Bronze rows'       AS metric, COUNT(*)::VARCHAR AS value FROM bronze_events
UNION ALL
SELECT 'Silver rows',   COUNT(*)::VARCHAR FROM silver_events
UNION ALL
SELECT 'Gold sales rows', COUNT(*)::VARCHAR FROM gold_daily_sales
UNION ALL
SELECT 'Cast failures (event_ts)',
    COUNT_IF(event_ts IS NULL AND event_ts_raw IS NOT NULL)::VARCHAR
FROM silver_events
UNION ALL
SELECT 'Cast failures (customer_id)',
    COUNT_IF(customer_id IS NULL AND customer_id_raw IS NOT NULL)::VARCHAR
FROM silver_events;

-- ============================================================================
-- For full DMF patterns (custom DMFs, anomaly detection, tag-based masking,
-- notifications), see:
--   guide-data-quality-governance/README.md
--   https://docs.snowflake.com/en/user-guide/data-quality-intro
-- ============================================================================
