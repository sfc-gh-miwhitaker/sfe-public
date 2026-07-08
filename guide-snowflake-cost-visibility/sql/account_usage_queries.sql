-- ============================================================
-- Account Usage Cost Attribution Queries
-- ============================================================
-- This file contains a library of METERING_DAILY_HISTORY queries
-- for understanding where Snowflake credits are going.
--
-- All queries use explicit column lists and date predicates to stay
-- performant against the ACCOUNT_USAGE views.
--
-- Required: GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;
-- Latency: METERING_DAILY_HISTORY has up to 3-hour lag. Use for trend analysis,
--          not real-time monitoring.
-- ============================================================

USE ROLE ACCOUNTADMIN;  -- or any role with IMPORTED PRIVILEGES on SNOWFLAKE DB

-- ── QUERY 1: SERVICE TYPE BREAKDOWN ──────────────────────────────────────────
-- The starting point for any cost governance conversation.
-- Shows total credits by service type over the last 30 days.
-- Run this first to identify which service is your biggest cost driver.

SELECT
    service_type,
    SUM(credits_used)   AS total_credits_used,
    SUM(credits_billed) AS total_credits_billed,
    ROUND(
        100.0 * SUM(credits_billed) / NULLIF(SUM(SUM(credits_billed)) OVER (), 0),
        1
    ) AS pct_of_total
FROM snowflake.account_usage.metering_daily_history
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY service_type
ORDER BY total_credits_billed DESC;

-- Common SERVICE_TYPE values:
--   WAREHOUSE_METERING       — virtual warehouse compute
--   AI_SERVICES              — Cortex AI Functions, Cortex Analyst
--   AUTO_CLUSTERING          — automatic table reclustering
--   DYNAMIC_TABLE_MAINTENANCE — Dynamic Table refresh
--   SERVERLESS_TASK          — tasks running on serverless compute
--   MATERIALIZED_VIEW        — materialized view maintenance
--   SEARCH_OPTIMIZATION      — Search Optimization Service
--   CORTEX_CODE_CLI          — Cortex Code CLI usage
--   CORTEX_CODE_SNOWSIGHT    — Cortex Code in Snowsight
--   SNOWPIPE_STREAMING       — Snowpipe Streaming ingestion
--   REPLICATION              — cross-region data replication


-- ── QUERY 2: 30-DAY DAILY TREND ──────────────────────────────────────────────
-- Shows daily credit consumption over the past 30 days, broken out by service.
-- Use this to spot acceleration or deceleration in any service type.

SELECT
    usage_date,
    service_type,
    credits_used,
    credits_billed
FROM snowflake.account_usage.metering_daily_history
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY usage_date DESC, credits_billed DESC;


-- ── QUERY 3: MONTH-OVER-MONTH COMPARISON ─────────────────────────────────────
-- Compares this month's spend to last month's spend by service type.
-- Identifies which services are growing fastest.

WITH current_month AS (
    SELECT
        service_type,
        SUM(credits_billed) AS credits_this_month
    FROM snowflake.account_usage.metering_daily_history
    WHERE usage_date >= DATE_TRUNC('month', CURRENT_DATE())
    GROUP BY service_type
),
last_month AS (
    SELECT
        service_type,
        SUM(credits_billed) AS credits_last_month
    FROM snowflake.account_usage.metering_daily_history
    WHERE usage_date >= DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()))
      AND usage_date  < DATE_TRUNC('month', CURRENT_DATE())
    GROUP BY service_type
)
SELECT
    COALESCE(c.service_type, l.service_type)     AS service_type,
    COALESCE(c.credits_this_month, 0)            AS credits_this_month,
    COALESCE(l.credits_last_month, 0)            AS credits_last_month,
    COALESCE(c.credits_this_month, 0)
        - COALESCE(l.credits_last_month, 0)      AS delta,
    CASE
        WHEN COALESCE(l.credits_last_month, 0) = 0 THEN NULL
        ELSE ROUND(
            100.0 * (COALESCE(c.credits_this_month, 0) - l.credits_last_month)
                / l.credits_last_month,
            1
        )
    END                                           AS pct_change
FROM current_month  c
FULL OUTER JOIN last_month l USING (service_type)
ORDER BY credits_this_month DESC;


-- ── QUERY 4: WAREHOUSE BREAKDOWN ─────────────────────────────────────────────
-- Which warehouses are the largest consumers this month?
-- Uses WAREHOUSE_METERING_HISTORY for warehouse-level granularity.

SELECT
    warehouse_name,
    SUM(credits_used_compute)        AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_services_credits,
    SUM(credits_used)                AS total_credits,
    COUNT(DISTINCT DATE(start_time)) AS active_days
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATE_TRUNC('month', CURRENT_DATE())
GROUP BY warehouse_name
ORDER BY total_credits DESC
LIMIT 25;


-- ── QUERY 5: WAREHOUSE DAILY TREND ───────────────────────────────────────────
-- Daily compute spend for the top warehouses over the past 30 days.
-- Useful for identifying warehouses with unusual activity patterns.

SELECT
    DATE(start_time)                 AS usage_date,
    warehouse_name,
    SUM(credits_used_compute)        AS compute_credits,
    SUM(credits_used)                AS total_credits
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY DATE(start_time), warehouse_name
ORDER BY usage_date DESC, total_credits DESC;


-- ── QUERY 6: TOP USERS BY QUERY COUNT AND DURATION ───────────────────────────
-- Which users are running the most queries and for how long?
-- Note: QUERY_HISTORY doesn't have a direct credits column;
-- cloud_services_credits is the available credit signal here.

SELECT
    user_name,
    warehouse_name,
    COUNT(*)                                               AS query_count,
    ROUND(SUM(total_elapsed_time) / 1000.0, 0)            AS total_elapsed_ms,
    ROUND(SUM(total_elapsed_time) / 1000.0 / 3600.0, 2)  AS total_hours,
    SUM(credits_used_cloud_services)                       AS cloud_credits,
    AVG(total_elapsed_time / 1000.0)                      AS avg_elapsed_sec
FROM snowflake.account_usage.query_history
WHERE start_time >= DATE_TRUNC('month', CURRENT_DATE())
  AND execution_status = 'SUCCESS'
  AND warehouse_name IS NOT NULL
GROUP BY user_name, warehouse_name
ORDER BY cloud_credits DESC
LIMIT 30;


-- ── QUERY 7: AI SERVICES SPEND ────────────────────────────────────────────────
-- Break out AI_SERVICES spend from METERING_DAILY_HISTORY.
-- For per-function AI usage, see guide-cortex-ai-cost-controls for the
-- 14 AI usage views in ACCOUNT_USAGE.

SELECT
    usage_date,
    service_type,
    credits_used,
    credits_billed
FROM snowflake.account_usage.metering_daily_history
WHERE service_type = 'AI_SERVICES'
  AND usage_date >= DATEADD('day', -90, CURRENT_DATE())
ORDER BY usage_date DESC;

-- Month-by-month AI services trend:
SELECT
    DATE_TRUNC('month', usage_date) AS month,
    SUM(credits_used)               AS ai_credits_used,
    SUM(credits_billed)             AS ai_credits_billed
FROM snowflake.account_usage.metering_daily_history
WHERE service_type = 'AI_SERVICES'
  AND usage_date >= DATEADD('month', -12, CURRENT_DATE())
GROUP BY DATE_TRUNC('month', usage_date)
ORDER BY month DESC;


-- ── QUERY 8: SERVERLESS AND BACKGROUND SERVICES BREAKDOWN ────────────────────
-- Surfaces all non-warehouse credit consumption.
-- Useful when total spend exceeds warehouse spend by a meaningful amount.

SELECT
    service_type,
    SUM(credits_used)   AS credits_used,
    SUM(credits_billed) AS credits_billed
FROM snowflake.account_usage.metering_daily_history
WHERE service_type NOT IN ('WAREHOUSE_METERING', 'WAREHOUSE_METERING_READER')
  AND usage_date >= DATE_TRUNC('month', CURRENT_DATE())
GROUP BY service_type
ORDER BY credits_billed DESC;


-- ── QUERY 9: LONG-RUNNING QUERIES (POTENTIAL WASTE) ──────────────────────────
-- Queries running longer than 10 minutes that may indicate missing optimizations.

SELECT
    query_id,
    user_name,
    warehouse_name,
    warehouse_size,
    query_type,
    ROUND(total_elapsed_time / 1000.0, 0) AS elapsed_seconds,
    ROUND(compilation_time    / 1000.0, 0) AS compile_seconds,
    ROUND(execution_time      / 1000.0, 0) AS execute_seconds,
    partitions_scanned,
    partitions_total,
    LEFT(query_text, 200)                  AS query_preview
FROM snowflake.account_usage.query_history
WHERE start_time >= DATEADD('day', -7, CURRENT_DATE())
  AND total_elapsed_time > 600000  -- 10 minutes in milliseconds
  AND execution_status = 'SUCCESS'
ORDER BY total_elapsed_time DESC
LIMIT 25;


-- ── QUERY 10: CLOUD SERVICES ADJUSTMENT CHECK ────────────────────────────────
-- Cloud services usage is only billed above 10% of daily warehouse usage.
-- This query shows days where cloud services exceeded the threshold,
-- and therefore contributed to the actual bill.

SELECT
    usage_date,
    credits_used_cloud_services,
    credits_adjustment_cloud_services,
    credits_used_cloud_services + credits_adjustment_cloud_services AS billed_cloud_services
FROM snowflake.account_usage.metering_daily_history
WHERE usage_date >= DATEADD('month', -1, CURRENT_DATE())
  AND service_type = 'WAREHOUSE_METERING'
  AND credits_adjustment_cloud_services < 0  -- adjustment means cloud services were billed
ORDER BY billed_cloud_services DESC;
