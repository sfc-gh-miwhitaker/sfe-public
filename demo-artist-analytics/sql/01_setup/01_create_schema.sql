/*==============================================================================
  01_setup/01_create_schema.sql
  Artist Analytics — Schema Setup
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS
  COMMENT = 'DEMO: Music artist analytics — streams, social, income, momentum (Expires: 2026-08-23)';

USE SCHEMA SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;

SELECT 'Schema SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS ready' AS step_01_setup;
