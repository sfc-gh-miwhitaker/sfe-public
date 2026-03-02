-- ============================================================================
-- Script: sql/02_data/01_create_tables.sql
-- Purpose: Create raw and staging tables for quality metrics.
-- Target: SNOWFLAKE_EXAMPLE.DATA_QUALITY tables.
-- Deps: SNOWFLAKE_EXAMPLE.DATA_QUALITY schema exists.
-- Note: TRANSIENT tables used for demo data (no Fail-safe, lower storage cost).
-- ============================================================================

CREATE OR REPLACE TRANSIENT TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE (
  athlete_id VARCHAR NOT NULL,
  ngb_code VARCHAR NOT NULL,
  sport VARCHAR NOT NULL,
  event_date DATE NOT NULL,
  metric_type VARCHAR NOT NULL,
  metric_value FLOAT,
  data_source VARCHAR NOT NULL,
  load_timestamp TIMESTAMP_NTZ NOT NULL
)
COMMENT = 'DEMO: Raw athlete performance events | Author: SE Community | Expires: 2026-05-01';

CREATE OR REPLACE TRANSIENT TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT (
  engagement_id VARCHAR NOT NULL,
  fan_id VARCHAR NOT NULL,
  channel VARCHAR NOT NULL,
  event_type VARCHAR NOT NULL,
  engagement_timestamp TIMESTAMP_NTZ NOT NULL,
  session_duration INTEGER,
  conversion_flag BOOLEAN
)
COMMENT = 'DEMO: Raw fan engagement events | Author: SE Community | Expires: 2026-05-01';

CREATE OR REPLACE TRANSIENT TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.STG_DATA_QUALITY_METRICS (
  metric_date DATE NOT NULL,
  table_name VARCHAR NOT NULL,
  metric_name VARCHAR NOT NULL,
  metric_value FLOAT,
  records_evaluated INTEGER NOT NULL,
  failures_detected INTEGER NOT NULL,
  created_at TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: Data quality metric results | Author: SE Community | Expires: 2026-05-01';
