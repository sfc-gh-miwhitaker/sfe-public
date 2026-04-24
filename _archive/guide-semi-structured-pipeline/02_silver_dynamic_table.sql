/*==============================================================================
SILVER DYNAMIC TABLE
Semi-Structured Data Pipeline Architecture Guide

Silver is where raw VARIANT data becomes structured and safe. TRY_CAST makes
failures visible; _raw columns preserve original values for debugging.

Prerequisite: Run 01_bronze_setup.sql first.

Docs:
  - TRY_CAST:   https://docs.snowflake.com/en/sql-reference/functions/try_cast
  - FLATTEN:    https://docs.snowflake.com/en/sql-reference/functions/flatten
  - QUALIFY:    https://docs.snowflake.com/en/sql-reference/constructs/qualify
  - Dynamic Tables: https://docs.snowflake.com/en/user-guide/dynamic-tables-about
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA SEMI_STRUCTURED_PIPELINE;
USE WAREHOUSE SFE_PIPELINE_WH;

-- ============================================================================
-- STEP 1: Create silver Dynamic Table
--
-- TRY_CAST returns NULL on conversion failure (same as VARIANT :: extraction).
-- The value of this pattern is keeping BOTH the raw string and the typed result
-- so you can DETECT failures instead of silently losing data.
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE silver_events
    TARGET_LAG = '10 minutes'
    WAREHOUSE = SFE_PIPELINE_WH
AS
SELECT
    raw_data:event_id::VARCHAR                    AS event_id_raw,
    TRY_CAST(raw_data:event_id AS NUMBER)         AS event_id,

    raw_data:event_ts::VARCHAR                    AS event_ts_raw,
    TRY_CAST(raw_data:event_ts AS TIMESTAMP_NTZ)  AS event_ts,

    raw_data:customer_id::VARCHAR                 AS customer_id_raw,
    TRY_CAST(raw_data:customer_id AS NUMBER)      AS customer_id,

    raw_data:store_code::VARCHAR                  AS store_code,
    raw_data:event_type::VARCHAR                  AS event_type,

    TRY_CAST(raw_data:quantity AS NUMBER)          AS quantity,
    TRY_CAST(raw_data:unit_price AS FLOAT)         AS unit_price,

    raw_data:product.name::VARCHAR                AS product_name,
    raw_data:product.category::VARCHAR            AS product_category,

    source_file,
    file_row_number,
    load_ts
FROM bronze_events;

-- ============================================================================
-- STEP 2: Verify silver data and check for cast failures
-- Rows where the typed column is NULL but the raw column is NOT NULL indicate
-- a conversion failure. These are the rows that would silently vanish with
-- bare :: casts.
-- ============================================================================

SELECT event_id_raw, event_ts_raw, customer_id_raw, source_file, file_row_number
FROM silver_events
WHERE (event_id IS NULL AND event_id_raw IS NOT NULL)
   OR (event_ts IS NULL AND event_ts_raw IS NOT NULL)
   OR (customer_id IS NULL AND customer_id_raw IS NOT NULL);

-- ============================================================================
-- STEP 3: Silver Dynamic Table for nested/array data
-- Uses LATERAL FLATTEN to explode arrays into rows.
-- Path notation (raw_data:customer.name) navigates nested objects.
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE silver_order_items
    TARGET_LAG = '10 minutes'
    WAREHOUSE = SFE_PIPELINE_WH
AS
SELECT
    raw_data:event_id::VARCHAR                 AS event_id_raw,
    TRY_CAST(raw_data:event_id AS NUMBER)      AS event_id,
    raw_data:customer_id::VARCHAR              AS customer_id_raw,
    TRY_CAST(raw_data:customer_id AS NUMBER)   AS customer_id,
    raw_data:store_code::VARCHAR               AS store_code,
    item.value:product_name::VARCHAR           AS product_name,
    TRY_CAST(item.value:quantity AS NUMBER)     AS quantity,
    TRY_CAST(item.value:price AS FLOAT)        AS unit_price,
    source_file,
    load_ts
FROM bronze_events,
    LATERAL FLATTEN(input => raw_data:items) item
WHERE raw_data:items IS NOT NULL;

-- ============================================================================
-- STEP 4: Deduplication pattern with QUALIFY
-- If the same event arrives in multiple files, keep only the latest load.
-- ROW_NUMBER partitions by business key, orders by load timestamp descending.
-- ============================================================================

SELECT
    event_id,
    event_ts,
    customer_id,
    store_code,
    source_file,
    load_ts
FROM silver_events
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY event_id
    ORDER BY load_ts DESC
) = 1;

-- ============================================================================
-- STEP 5: Verify silver tables
-- ============================================================================

SELECT 'silver_events' AS dt_name, COUNT(*) AS row_count FROM silver_events
UNION ALL
SELECT 'silver_order_items', COUNT(*) FROM silver_order_items;
