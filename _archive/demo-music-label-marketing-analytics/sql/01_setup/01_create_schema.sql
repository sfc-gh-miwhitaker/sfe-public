/*==============================================================================
SETUP - Music Label Marketing Analytics
Creates schema and warehouse for the demo.
==============================================================================*/

USE ROLE SYSADMIN;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING
  COMMENT = 'DEMO: Music label marketing analytics — budget tracking, AI enrichment, and campaign ROI (Expires: 2026-04-24)';

CREATE WAREHOUSE IF NOT EXISTS SFE_MUSIC_MARKETING_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'DEMO: Music label marketing analytics compute (Expires: 2026-04-24)';

USE WAREHOUSE SFE_MUSIC_MARKETING_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.MUSIC_MARKETING;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared schema for semantic views across demo projects';
