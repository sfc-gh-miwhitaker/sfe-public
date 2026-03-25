/*==============================================================================
SCHEMA EVOLUTION
Semi-Structured Data Pipeline Architecture Guide

Semi-structured data evolves: new fields appear, types change, optional fields
become required. This workbook covers the 4-step lifecycle:
  1. DETECT new keys
  2. REVIEW and classify the change
  3. LOG the change
  4. REBUILD the DT chain

Prerequisite: Run 01-03 workbooks first.

Docs:
  - INFER_SCHEMA:      https://docs.snowflake.com/en/sql-reference/functions/infer_schema
  - Schema Evolution:  https://docs.snowflake.com/en/user-guide/data-load-schema-evolution
  - TYPEOF:            https://docs.snowflake.com/en/sql-reference/functions/typeof
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA SEMI_STRUCTURED_PIPELINE;
USE WAREHOUSE SFE_PIPELINE_WH;

-- ============================================================================
-- STEP 1: Detect keys using INFER_SCHEMA (files on stage)
-- Works when files are still available on the stage.
-- ============================================================================

-- Uncomment when you have files on stage:
-- SELECT *
-- FROM TABLE(
--     INFER_SCHEMA(
--         LOCATION => '@events_stage/',
--         FILE_FORMAT => 'ff_json'
--     )
-- );

-- ============================================================================
-- STEP 2: Detect keys using FLATTEN + TYPEOF (existing VARIANT data)
-- Works even after files are purged -- everything is in the VARIANT column.
-- ============================================================================

SELECT DISTINCT
    f.key                                        AS column_name,
    TYPEOF(f.value)                              AS detected_type,
    COUNT(*) OVER (PARTITION BY f.key)           AS row_count,
    COUNT(*) OVER ()                             AS total_rows
FROM bronze_events,
    LATERAL FLATTEN(input => raw_data) f
ORDER BY column_name;

-- ============================================================================
-- STEP 3: Compare detected keys against existing silver columns
-- Keys in bronze that are NOT in silver are candidates for schema evolution.
-- ============================================================================

WITH bronze_keys AS (
    SELECT DISTINCT
        f.key           AS column_name,
        TYPEOF(f.value) AS detected_type
    FROM bronze_events,
        LATERAL FLATTEN(input => raw_data) f
),
silver_columns AS (
    SELECT column_name
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = CURRENT_SCHEMA()
      AND table_name = 'SILVER_EVENTS'
)
SELECT
    bk.column_name,
    bk.detected_type,
    CASE
        WHEN sc.column_name IS NOT NULL THEN 'EXISTS'
        ELSE 'NEW - needs review'
    END AS status
FROM bronze_keys bk
LEFT JOIN silver_columns sc
    ON UPPER(bk.column_name) = UPPER(sc.column_name)
       OR UPPER(bk.column_name) || '_RAW' = UPPER(sc.column_name)
ORDER BY status DESC, bk.column_name;

-- ============================================================================
-- STEP 4: Create schema evolution audit log
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_evolution_log (
    detected_at   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    source_table  VARCHAR,
    column_name   VARCHAR,
    detected_type VARCHAR,
    change_type   VARCHAR,
    applied       BOOLEAN DEFAULT FALSE,
    applied_at    TIMESTAMP_LTZ,
    applied_by    VARCHAR
);

-- ============================================================================
-- STEP 5: Log a detected change (example)
-- In production, a scheduled stored procedure would do this automatically.
-- ============================================================================

-- Example: a new 'loyalty_tier' field was detected
INSERT INTO schema_evolution_log (source_table, column_name, detected_type, change_type)
VALUES ('bronze_events', 'loyalty_tier', 'VARCHAR', 'NEW_KEY_ADDITIVE');

SELECT * FROM schema_evolution_log ORDER BY detected_at DESC;

-- ============================================================================
-- STEP 6: Rebuild silver DT with new column
-- CREATE OR REPLACE rebuilds the DT definition. Snowflake re-materializes
-- the table from the updated query.
-- ============================================================================

-- After review, add the new column to silver:
--
-- CREATE OR REPLACE DYNAMIC TABLE silver_events
--     TARGET_LAG = '10 minutes'
--     WAREHOUSE = SFE_PIPELINE_WH
-- AS
-- SELECT
--     ... existing columns ...,
--     raw_data:loyalty_tier::VARCHAR             AS loyalty_tier_raw,
--     TRY_CAST(raw_data:loyalty_tier AS VARCHAR) AS loyalty_tier,
--     source_file,
--     file_row_number,
--     load_ts
-- FROM bronze_events;

-- Then update the log:
-- UPDATE schema_evolution_log
-- SET applied = TRUE,
--     applied_at = CURRENT_TIMESTAMP(),
--     applied_by = CURRENT_USER()
-- WHERE column_name = 'loyalty_tier'
--   AND applied = FALSE;

-- ============================================================================
-- STEP 7: Detect nested keys (for deeply nested JSON)
-- Recursively flattens nested objects to discover all paths.
-- ============================================================================

SELECT DISTINCT
    f.path                AS json_path,
    f.key                 AS field_name,
    TYPEOF(f.value)       AS detected_type
FROM bronze_events,
    LATERAL FLATTEN(input => raw_data, RECURSIVE => TRUE) f
WHERE TYPEOF(f.value) NOT IN ('OBJECT', 'ARRAY')
ORDER BY json_path;

-- ============================================================================
-- Change type classification reference
--
-- | Change Type                        | Risk   | Action                      |
-- |------------------------------------|--------|-----------------------------|
-- | New key (additive)                 | Low    | Auto-add column, rebuild DT |
-- | Key removed                        | Medium | Keep column, NULLs expected |
-- | Type change (e.g. INTEGER->VARCHAR)| High   | Alert team, do NOT auto-apply|
-- | Key renamed                        | High   | Alert team, manual mapping  |
-- ============================================================================
