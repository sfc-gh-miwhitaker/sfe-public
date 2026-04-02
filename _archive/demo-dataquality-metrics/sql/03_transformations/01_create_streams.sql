-- ============================================================================
-- Script: sql/03_transformations/01_create_streams.sql
-- Purpose: Create streams to capture RAW table inserts.
-- Target: SNOWFLAKE_EXAMPLE.DATA_QUALITY streams on RAW tables.
-- Deps: RAW tables exist.
-- ============================================================================

CREATE OR REPLACE STREAM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE_STREAM
  ON TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE
  COMMENT = 'DEMO: Stream for athlete performance changes | Author: SE Community | Expires: 2026-05-01';

CREATE OR REPLACE STREAM SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT_STREAM
  ON TABLE SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT
  COMMENT = 'DEMO: Stream for fan engagement changes | Author: SE Community | Expires: 2026-05-01';
