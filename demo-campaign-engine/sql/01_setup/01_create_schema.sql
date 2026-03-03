/*==============================================================================
CREATE SCHEMA
Generated from prompt: "Set up the project schema and warehouse for the
  casino campaign recommendation engine."
Tool: Cursor + Claude | Refined: 1 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-01
==============================================================================*/

USE ROLE ACCOUNTADMIN;
GRANT APPLICATION ROLE SNOWFLAKE.MODELS."CORTEX-MODEL-ROLE-ALL" TO ROLE SYSADMIN;

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE
  COMMENT = 'DEMO: Casino campaign recommendation engine with ML targeting and vector lookalike (Expires: 2026-05-01)';

CREATE WAREHOUSE IF NOT EXISTS SFE_CAMPAIGN_ENGINE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Campaign engine compute (Expires: 2026-05-01)';

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

-- Shared schema for semantic views (idempotent)
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared semantic views for Cortex Intelligence agents';

-- Grant ML model creation privilege
GRANT CREATE SNOWFLAKE.ML.CLASSIFICATION ON SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE
  TO ROLE SYSADMIN;
