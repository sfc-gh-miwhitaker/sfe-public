-- ============================================================================
-- Script: sql/03_transformations/02_create_views.sql
-- Purpose: Create data metric functions and reporting views.
-- Target: SNOWFLAKE_EXAMPLE.DATA_QUALITY DMFs and views.
-- Deps: RAW tables and STG_DATA_QUALITY_METRICS exist.
-- ============================================================================

-- Data metric functions require a schedule to be set on the target tables.
-- TRIGGER_ON_CHANGES: DMFs run automatically when data is modified (event-driven, not polling).
-- NOTE: Schedule takes ~10 minutes to activate after initial setup.
ALTER TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE
  SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

ALTER TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT
  SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

CREATE OR REPLACE DATA METRIC FUNCTION SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_METRIC_VALUE_VALID_PCT (
  t TABLE (metric_value FLOAT)
)
RETURNS NUMBER
COMMENT = 'DEMO: Metric value validity percent | Author: SE Community | Expires: 2026-02-14'
AS
$$
  SELECT ROUND(
    100 * (COUNT_IF(t.metric_value BETWEEN 0 AND 100) / NULLIF(COUNT(*), 0)),
    2
  )
  FROM t
$$;

CREATE OR REPLACE DATA METRIC FUNCTION SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_SESSION_DURATION_VALID_PCT (
  t TABLE (session_duration INTEGER)
)
RETURNS NUMBER
COMMENT = 'DEMO: Session duration validity percent | Author: SE Community | Expires: 2026-02-14'
AS
$$
  SELECT ROUND(
    100 * (COUNT_IF(t.session_duration BETWEEN 0 AND 14400) / NULLIF(COUNT(*), 0)),
    2
  )
  FROM t
$$;

-- Associate DMFs with EXPECTATIONS (thresholds that define pass/fail)
-- Uses scripting: try drop association (ignore error), then add fresh with expectation
EXECUTE IMMEDIATE $$
BEGIN
  -- Athlete Performance DMF: drop association if exists, then add with expectation
  BEGIN
    ALTER TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE
      DROP DATA METRIC FUNCTION SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_METRIC_VALUE_VALID_PCT ON (metric_value);
  EXCEPTION WHEN OTHER THEN NULL;
  END;
  ALTER TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE
    ADD DATA METRIC FUNCTION SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_METRIC_VALUE_VALID_PCT ON (metric_value)
    EXPECTATION validity_threshold (VALUE >= 90);

  -- Fan Engagement DMF: drop association if exists, then add with expectation
  BEGIN
    ALTER TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT
      DROP DATA METRIC FUNCTION SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_SESSION_DURATION_VALID_PCT ON (session_duration);
  EXCEPTION WHEN OTHER THEN NULL;
  END;
  ALTER TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT
    ADD DATA METRIC FUNCTION SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_SESSION_DURATION_VALID_PCT ON (session_duration)
    EXPECTATION validity_threshold (VALUE >= 90);
END;
$$;

-- Cleaned views filter out records that fail data quality checks.
-- These provide a "golden" dataset for downstream analytics.

CREATE OR REPLACE VIEW SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_ATHLETE_PERFORMANCE
  COMMENT = 'DEMO: Cleaned athlete performance view (valid metric_value only) | Author: SE Community | Expires: 2026-02-14'
AS
SELECT
  athlete_id,
  ngb_code,
  sport,
  event_date,
  metric_type,
  metric_value,
  data_source,
  load_timestamp
FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE
WHERE metric_value IS NOT NULL
  AND metric_value BETWEEN 0 AND 100;

CREATE OR REPLACE VIEW SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_FAN_ENGAGEMENT
  COMMENT = 'DEMO: Cleaned fan engagement view (valid session_duration only) | Author: SE Community | Expires: 2026-02-14'
AS
SELECT
  engagement_id,
  fan_id,
  channel,
  event_type,
  engagement_timestamp,
  session_duration,
  conversion_flag
FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT
WHERE session_duration IS NOT NULL
  AND session_duration BETWEEN 0 AND 14400;

CREATE OR REPLACE VIEW SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_DATA_QUALITY_METRICS
  COMMENT = 'DEMO: Data quality metrics view | Author: SE Community | Expires: 2026-02-14'
AS
SELECT
  metric_date,
  table_name,
  metric_name,
  metric_value,
  records_evaluated,
  failures_detected
FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.STG_DATA_QUALITY_METRICS;

CREATE OR REPLACE VIEW SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_QUALITY_SCORE_TREND
  COMMENT = 'DEMO: Quality score trend view | Author: SE Community | Expires: 2026-02-14'
AS
SELECT
  metric_date,
  table_name,
  ROUND(AVG(metric_value), 2) AS avg_quality_score,
  SUM(failures_detected) AS failures_detected
FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.STG_DATA_QUALITY_METRICS
GROUP BY
  metric_date,
  table_name;
