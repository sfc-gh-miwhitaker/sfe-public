/*==============================================================================
GOLD DYNAMIC TABLES
Semi-Structured Data Pipeline Architecture Guide

Gold is the analytics-ready layer. Fully typed, business-named columns.
Multiple gold DTs can read from one silver DT, each with its own TARGET_LAG.

Prerequisite: Run 01_bronze_setup.sql and 02_silver_dynamic_table.sql first.

Docs:
  - Dynamic Tables:  https://docs.snowflake.com/en/user-guide/dynamic-tables-about
  - TARGET_LAG:      https://docs.snowflake.com/en/user-guide/dynamic-tables-target-lag
  - DT Chains:       https://docs.snowflake.com/en/user-guide/dynamic-tables-create
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA SEMI_STRUCTURED_PIPELINE;
USE WAREHOUSE SFE_PIPELINE_WH;

-- ============================================================================
-- STEP 1: Gold DT -- Daily Sales
-- Aggregated by date and store. Filters out rows with failed casts (NULL IDs)
-- so only clean data reaches business users.
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE gold_daily_sales
    TARGET_LAG = '30 minutes'
    WAREHOUSE = SFE_PIPELINE_WH
AS
SELECT
    event_ts::DATE              AS sale_date,
    store_code,
    product_name,
    product_category,
    SUM(quantity)               AS total_quantity,
    SUM(quantity * unit_price)  AS total_revenue,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM silver_events
WHERE event_type = 'SALE'
  AND event_id IS NOT NULL
  AND event_ts IS NOT NULL
GROUP BY sale_date, store_code, product_name, product_category;

-- ============================================================================
-- STEP 2: Gold DT -- Customer 360
-- Customer-level lifetime metrics. Same silver source, different aggregation.
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE gold_customer_360
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_PIPELINE_WH
AS
SELECT
    customer_id,
    MIN(event_ts)                   AS first_seen,
    MAX(event_ts)                   AS last_seen,
    COUNT(DISTINCT event_ts::DATE)  AS active_days,
    COUNT(DISTINCT store_code)      AS stores_visited,
    SUM(CASE WHEN event_type = 'SALE' THEN quantity * unit_price ELSE 0 END)
                                    AS lifetime_revenue,
    SUM(CASE WHEN event_type = 'SALE' THEN quantity ELSE 0 END)
                                    AS lifetime_units
FROM silver_events
WHERE customer_id IS NOT NULL
GROUP BY customer_id;

-- ============================================================================
-- STEP 3: Gold DT -- Product Performance
-- Product-level metrics across all stores.
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE gold_product_performance
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_PIPELINE_WH
AS
SELECT
    product_name,
    product_category,
    COUNT(DISTINCT store_code)       AS stores_selling,
    SUM(quantity)                    AS total_units_sold,
    SUM(quantity * unit_price)       AS total_revenue,
    AVG(unit_price)                  AS avg_unit_price,
    COUNT(DISTINCT customer_id)      AS unique_buyers
FROM silver_events
WHERE event_type = 'SALE'
  AND product_name IS NOT NULL
GROUP BY product_name, product_category;

-- ============================================================================
-- STEP 4: Verify gold tables
-- ============================================================================

SELECT 'gold_daily_sales' AS dt_name, COUNT(*) AS row_count FROM gold_daily_sales
UNION ALL
SELECT 'gold_customer_360', COUNT(*) FROM gold_customer_360
UNION ALL
SELECT 'gold_product_performance', COUNT(*) FROM gold_product_performance;

-- ============================================================================
-- STEP 5: Verify the DT chain
-- Shows all Dynamic Tables and their refresh status.
-- ============================================================================

SHOW DYNAMIC TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.SEMI_STRUCTURED_PIPELINE;

-- ============================================================================
-- TARGET_LAG reference
--
-- | Scenario                          | Suggested TARGET_LAG  | Cost     |
-- |-----------------------------------|-----------------------|----------|
-- | Near-real-time dashboards         | 1-5 minutes           | Higher   |
-- | Operational reporting             | 10-30 minutes         | Moderate |
-- | Daily analytics / batch           | 1-6 hours             | Lower    |
-- | Intermediate DT (no direct users) | DOWNSTREAM            | Minimal  |
--
-- DOWNSTREAM defers refresh to downstream consumers. If no downstream DT
-- defines a concrete lag, a DOWNSTREAM DT will NOT refresh at all.
-- See: https://docs.snowflake.com/en/user-guide/dynamic-tables-target-lag
-- ============================================================================
