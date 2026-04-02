-- ============================================================================
-- Script: tools/insert_sample_data.sql
-- Purpose: Insert additional sample data to demonstrate live data quality updates.
-- Usage: Run this script in Snowsight to trigger stream/task/DMF processing.
-- ============================================================================

USE WAREHOUSE SFE_DATA_QUALITY_WH;

-- Insert 100 new athlete performance records (some with quality issues)
INSERT INTO SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE (
  athlete_id, ngb_code, sport, event_date, metric_type, metric_value, data_source, load_timestamp
)
WITH base AS (
  SELECT SEQ4() + 100000 AS row_id FROM TABLE(GENERATOR(ROWCOUNT => 100))
)
SELECT
  'A-' || LPAD(row_id::STRING, 6, '0'),
  CASE MOD(row_id, 3) WHEN 0 THEN 'USA' WHEN 1 THEN 'GBR' ELSE 'CAN' END,
  CASE MOD(row_id, 2) WHEN 0 THEN 'Track' ELSE 'Swimming' END,
  CURRENT_DATE(),
  'score',
  CASE
    WHEN MOD(row_id, 10) = 0 THEN NULL           -- 10% NULL (quality issue)
    WHEN MOD(row_id, 10) = 1 THEN 150.0          -- 10% out of range (quality issue)
    ELSE ROUND(UNIFORM(50, 95, RANDOM())::FLOAT, 2)  -- 80% valid
  END,
  'live_demo',
  CURRENT_TIMESTAMP()
FROM base;

-- Insert 200 new fan engagement records (some with quality issues)
INSERT INTO SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT (
  engagement_id, fan_id, channel, event_type, engagement_timestamp, session_duration, conversion_flag
)
WITH base AS (
  SELECT SEQ4() + 200000 AS row_id FROM TABLE(GENERATOR(ROWCOUNT => 200))
)
SELECT
  'E-' || LPAD(row_id::STRING, 7, '0'),
  'F-' || LPAD(MOD(row_id, 1000)::STRING, 6, '0'),
  CASE MOD(row_id, 3) WHEN 0 THEN 'web' WHEN 1 THEN 'mobile' ELSE 'social' END,
  CASE MOD(row_id, 4) WHEN 0 THEN 'view' WHEN 1 THEN 'click' ELSE 'share' END,
  CURRENT_TIMESTAMP(),
  CASE
    WHEN MOD(row_id, 8) = 0 THEN NULL             -- 12.5% NULL (quality issue)
    WHEN MOD(row_id, 8) = 1 THEN 99999            -- 12.5% out of range (quality issue)
    ELSE UNIFORM(60, 1800, RANDOM())             -- 75% valid
  END,
  IFF(MOD(row_id, 15) = 0, TRUE, FALSE)
FROM base;

-- Show what was inserted
SELECT 'Inserted 100 athlete records and 200 fan engagement records' AS status;

-- Check stream status (should show new records)
SELECT
  'RAW_ATHLETE_PERFORMANCE_STREAM' AS stream_name,
  SYSTEM$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE_STREAM') AS has_data
UNION ALL
SELECT
  'RAW_FAN_ENGAGEMENT_STREAM',
  SYSTEM$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT_STREAM');

-- Note: The task runs every 5 minutes and will process this data.
-- Or manually execute the task:
-- EXECUTE TASK SNOWFLAKE_EXAMPLE.DATA_QUALITY.refresh_data_quality_metrics_task;
