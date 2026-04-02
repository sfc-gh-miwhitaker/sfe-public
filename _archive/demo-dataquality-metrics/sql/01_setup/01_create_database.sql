-- ============================================================================
-- Script: sql/01_setup/01_create_database.sql
-- Purpose: Create the SNOWFLAKE_EXAMPLE database for the demo.
-- Target: SNOWFLAKE_EXAMPLE database.
-- Deps: Role has CREATE DATABASE privilege.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Data Quality Metrics & Reporting Demo | Author: SE Community | Expires: 2026-05-01';
