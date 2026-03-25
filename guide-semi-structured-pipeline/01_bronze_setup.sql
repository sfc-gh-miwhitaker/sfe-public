/*==============================================================================
BRONZE LAYER SETUP
Semi-Structured Data Pipeline Architecture Guide

Run step-by-step in a Snowsight worksheet. Each section builds on the previous.
Pair-programmed by SE Community + Cortex Code

Docs:
  - Querying metadata:  https://docs.snowflake.com/en/user-guide/querying-metadata
  - Snowpipe:           https://docs.snowflake.com/en/user-guide/data-load-snowpipe-auto-s3
  - COPY INTO:          https://docs.snowflake.com/en/sql-reference/sql/copy-into-table
==============================================================================*/

-- ============================================================================
-- STEP 1: Create schema and warehouse
-- ============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMI_STRUCTURED_PIPELINE;

CREATE WAREHOUSE IF NOT EXISTS SFE_PIPELINE_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 300;

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA SEMI_STRUCTURED_PIPELINE;
USE WAREHOUSE SFE_PIPELINE_WH;

-- ============================================================================
-- STEP 2: Create file format objects
-- One per source type. Reusable across stages and COPY operations.
-- ============================================================================

CREATE FILE FORMAT IF NOT EXISTS ff_parquet
    TYPE = PARQUET;

CREATE FILE FORMAT IF NOT EXISTS ff_json
    TYPE = JSON
    STRIP_OUTER_ARRAY = TRUE;

CREATE FILE FORMAT IF NOT EXISTS ff_avro
    TYPE = AVRO;

-- ============================================================================
-- STEP 3: Create internal stage (replace with external stage for production)
-- ============================================================================

CREATE STAGE IF NOT EXISTS events_stage
    FILE_FORMAT = ff_json;

-- ============================================================================
-- STEP 4: Create bronze table
-- All 5 metadata columns for full lineage. VARIANT absorbs any schema.
--
-- Available metadata columns (docs: querying-metadata):
--   METADATA$FILENAME          - Full path to source file
--   METADATA$FILE_ROW_NUMBER   - Row position within file
--   METADATA$FILE_CONTENT_KEY  - Checksum (detects reloads of same file)
--   METADATA$FILE_LAST_MODIFIED - Source file modification timestamp
--   METADATA$START_SCAN_TIME   - When Snowflake began scanning (not used here)
-- ============================================================================

CREATE TABLE IF NOT EXISTS bronze_events (
    raw_data         VARIANT,
    source_file      VARCHAR       DEFAULT METADATA$FILENAME,
    file_row_number  NUMBER        DEFAULT METADATA$FILE_ROW_NUMBER,
    file_content_key VARCHAR       DEFAULT METADATA$FILE_CONTENT_KEY,
    file_modified_at TIMESTAMP_NTZ DEFAULT METADATA$FILE_LAST_MODIFIED,
    load_ts          TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- STEP 5: Create Snowpipe for auto-ingest
-- AUTO_INGEST = TRUE requires cloud notification setup:
--   S3:    SQS event notification
--   GCS:   Pub/Sub subscription
--   Azure: Event Grid subscription
-- See: https://docs.snowflake.com/en/user-guide/data-load-snowpipe-auto-s3
-- ============================================================================

CREATE PIPE IF NOT EXISTS pipe_events
    AUTO_INGEST = TRUE
AS
COPY INTO bronze_events (raw_data, source_file, file_row_number, file_content_key, file_modified_at, load_ts)
FROM (
    SELECT
        $1,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        METADATA$FILE_CONTENT_KEY,
        METADATA$FILE_LAST_MODIFIED,
        CURRENT_TIMESTAMP()
    FROM @events_stage/
)
FILE_FORMAT = (FORMAT_NAME = 'ff_json');

-- ============================================================================
-- STEP 6: Load sample data manually (for testing without Snowpipe)
-- In production, Snowpipe handles this automatically via cloud notifications.
-- ============================================================================

INSERT INTO bronze_events (raw_data, source_file, file_row_number, load_ts)
SELECT
    PARSE_JSON(column1),
    'manual_load/sample_events.json',
    ROW_NUMBER() OVER (ORDER BY 1),
    CURRENT_TIMESTAMP()
FROM VALUES
    ('{"event_id": 1001, "event_ts": "2026-03-25T14:30:00Z", "customer_id": 42, "store_code": "US-NYC-001", "event_type": "SALE", "quantity": 2, "unit_price": 3.99, "product": {"name": "Original Glazed", "category": "Glazed"}}'),
    ('{"event_id": 1002, "event_ts": "2026-03-25T15:00:00Z", "customer_id": 43, "store_code": "US-NYC-001", "event_type": "SALE", "quantity": 1, "unit_price": 4.49, "product": {"name": "Chocolate Iced", "category": "Chocolate"}}'),
    ('{"event_id": 1003, "event_ts": "03/25/2026", "customer_id": 44, "store_code": "JP-TKY-001", "event_type": "SALE", "quantity": 3, "unit_price": 350, "product": {"name": "抹茶グレーズド", "category": "Specialty"}}'),
    ('{"event_id": 1004, "event_ts": "2026-03-25T16:00:00Z", "customer_id": "not_a_number", "store_code": "FR-PAR-001", "event_type": "SALE", "quantity": 1, "unit_price": 2.50, "product": {"name": "Donut Glacé Original", "category": "Glazed"}}'),
    ('{"event_id": 1005, "event_ts": "2026-03-25T17:00:00Z", "customer_id": 46, "store_code": "US-NYC-001", "event_type": "RETURN", "quantity": -1, "unit_price": 3.99, "product": {"name": "Original Glazed", "category": "Glazed"}, "items": [{"product_name": "Original Glazed", "quantity": 1, "price": 3.99}]}');

-- ============================================================================
-- STEP 7: Verify bronze data
-- ============================================================================

SELECT
    raw_data,
    source_file,
    file_row_number,
    load_ts
FROM bronze_events
LIMIT 10;

SELECT 'Bronze setup complete. ' || COUNT(*) || ' rows loaded.' AS status
FROM bronze_events;
