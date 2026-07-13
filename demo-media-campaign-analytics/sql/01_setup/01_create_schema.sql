/*==============================================================================
  01_setup/01_create_schema.sql
  Media Campaign Analytics — Schema + Warehouse
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12
==============================================================================*/

USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SFE_MEDIA_CAMPAIGN_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'DEMO: Media campaign analytics compute (Expires: 2026-08-12)';

USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'Shared database for SE demo projects';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS
  COMMENT = 'DEMO: Paid media campaign performance analytics (Expires: 2026-08-12)';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared schema for semantic views across SE demo projects';
