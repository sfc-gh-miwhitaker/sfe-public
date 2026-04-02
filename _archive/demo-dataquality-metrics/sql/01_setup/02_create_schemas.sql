-- ============================================================================
-- Script: sql/01_setup/02_create_schemas.sql
-- Purpose: Create the DATA_QUALITY project schema.
-- Target: SNOWFLAKE_EXAMPLE.DATA_QUALITY schema.
-- Deps: SNOWFLAKE_EXAMPLE database exists.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.DATA_QUALITY
  COMMENT = 'DEMO: Data Quality Metrics & Reporting Demo - Project schema | Author: SE Community | Expires: 2026-05-01';
