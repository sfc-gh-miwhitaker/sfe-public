-- ============================================================================
-- Script: sql/02_data/02_load_sample_data.sql
-- Purpose: Load synthetic sample data into RAW tables.
-- Target: SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE and RAW_FAN_ENGAGEMENT.
-- Deps: RAW tables exist.
-- ============================================================================

INSERT INTO SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE (
  athlete_id,
  ngb_code,
  sport,
  event_date,
  metric_type,
  metric_value,
  data_source,
  load_timestamp
)
WITH base AS (
  SELECT
    SEQ4() AS row_id
  FROM TABLE(GENERATOR(ROWCOUNT => 10000))
)
SELECT
  'A-' || LPAD(row_id::STRING, 6, '0') AS athlete_id,
  CASE MOD(row_id, 5)
    WHEN 0 THEN 'USA'
    WHEN 1 THEN 'CAN'
    WHEN 2 THEN 'GBR'
    WHEN 3 THEN 'AUS'
    ELSE 'JPN'
  END AS ngb_code,
  CASE MOD(row_id, 4)
    WHEN 0 THEN 'Track'
    WHEN 1 THEN 'Swimming'
    WHEN 2 THEN 'Cycling'
    ELSE 'Gymnastics'
  END AS sport,
  DATEADD('day', -UNIFORM(0, 730, RANDOM()), CURRENT_DATE()) AS event_date,
  CASE MOD(row_id, 3)
    WHEN 0 THEN 'speed'
    WHEN 1 THEN 'score'
    ELSE 'rank'
  END AS metric_type,
  CASE
    WHEN MOD(row_id, 50) = 0 THEN NULL
    WHEN MOD(row_id, 50) = 1 THEN 999.0
    ELSE ROUND(UNIFORM(0, 100, RANDOM())::FLOAT, 2)
  END AS metric_value,
  CASE MOD(row_id, 3)
    WHEN 0 THEN 'partner_api'
    WHEN 1 THEN 'manual_upload'
    ELSE 'batch_feed'
  END AS data_source,
  DATEADD('minute', -UNIFORM(0, 10080, RANDOM()), CURRENT_TIMESTAMP()) AS load_timestamp
FROM base;

INSERT INTO SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT (
  engagement_id,
  fan_id,
  channel,
  event_type,
  engagement_timestamp,
  session_duration,
  conversion_flag
)
WITH base AS (
  SELECT
    SEQ4() AS row_id
  FROM TABLE(GENERATOR(ROWCOUNT => 50000))
)
SELECT
  'E-' || LPAD(row_id::STRING, 7, '0') AS engagement_id,
  'F-' || LPAD(MOD(row_id, 20000)::STRING, 6, '0') AS fan_id,
  CASE MOD(row_id, 3)
    WHEN 0 THEN 'web'
    WHEN 1 THEN 'mobile'
    ELSE 'social'
  END AS channel,
  CASE MOD(row_id, 4)
    WHEN 0 THEN 'view'
    WHEN 1 THEN 'click'
    WHEN 2 THEN 'share'
    ELSE 'conversion'
  END AS event_type,
  DATEADD('minute', -UNIFORM(0, 525600, RANDOM()), CURRENT_TIMESTAMP()) AS engagement_timestamp,
  CASE
    WHEN MOD(row_id, 33) = 0 THEN NULL
    ELSE UNIFORM(10, 3600, RANDOM())
  END AS session_duration,
  IFF(MOD(row_id, 20) = 0, TRUE, FALSE) AS conversion_flag
FROM base;
