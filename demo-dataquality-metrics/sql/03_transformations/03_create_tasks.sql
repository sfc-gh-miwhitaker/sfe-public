-- ============================================================================
-- Script: sql/03_transformations/03_create_tasks.sql
-- Purpose: Create and start the task that refreshes data quality metrics.
-- Target: SNOWFLAKE_EXAMPLE.DATA_QUALITY.refresh_data_quality_metrics_task.
-- Deps: Streams, STG_DATA_QUALITY_METRICS, and SFE_DATA_QUALITY_WH exist.
-- ============================================================================

CREATE OR REPLACE TASK SNOWFLAKE_EXAMPLE.DATA_QUALITY.refresh_data_quality_metrics_task
  WAREHOUSE = SFE_DATA_QUALITY_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'DEMO: Refresh data quality metrics | Author: SE Community | Expires: 2026-05-01'
AS
INSERT INTO SNOWFLAKE_EXAMPLE.DATA_QUALITY.STG_DATA_QUALITY_METRICS (
  metric_date,
  table_name,
  metric_name,
  metric_value,
  records_evaluated,
  failures_detected
)
WITH athlete_changes AS (
  SELECT
    athlete_id,
    ngb_code,
    sport,
    event_date,
    metric_type,
    metric_value,
    data_source,
    load_timestamp
  FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE_STREAM
  WHERE METADATA$ACTION = 'INSERT'
),
fan_changes AS (
  SELECT
    engagement_id,
    fan_id,
    channel,
    event_type,
    engagement_timestamp,
    session_duration,
    conversion_flag
  FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT_STREAM
  WHERE METADATA$ACTION = 'INSERT'
),
athlete_metrics AS (
  SELECT
    CURRENT_DATE() AS metric_date,
    'RAW_ATHLETE_PERFORMANCE' AS table_name,
    'metric_value_valid_pct' AS metric_name,
    ROUND(100 * (COUNT_IF(metric_value BETWEEN 0 AND 100) / NULLIF(COUNT(*), 0)), 2) AS metric_value,
    COUNT(*) AS records_evaluated,
    COUNT_IF(metric_value IS NULL OR metric_value < 0 OR metric_value > 100) AS failures_detected
  FROM athlete_changes
),
fan_metrics AS (
  SELECT
    CURRENT_DATE() AS metric_date,
    'RAW_FAN_ENGAGEMENT' AS table_name,
    'session_duration_valid_pct' AS metric_name,
    ROUND(100 * (COUNT_IF(session_duration BETWEEN 0 AND 14400) / NULLIF(COUNT(*), 0)), 2) AS metric_value,
    COUNT(*) AS records_evaluated,
    COUNT_IF(session_duration IS NULL OR session_duration < 0 OR session_duration > 14400) AS failures_detected
  FROM fan_changes
)
SELECT
  metric_date,
  table_name,
  metric_name,
  metric_value,
  records_evaluated,
  failures_detected
FROM athlete_metrics
UNION ALL
SELECT
  metric_date,
  table_name,
  metric_name,
  metric_value,
  records_evaluated,
  failures_detected
FROM fan_metrics;

ALTER TASK SNOWFLAKE_EXAMPLE.DATA_QUALITY.refresh_data_quality_metrics_task RESUME;
