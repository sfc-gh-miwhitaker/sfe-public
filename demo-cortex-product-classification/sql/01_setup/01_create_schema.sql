/*==============================================================================
SETUP - Glaze & Classify
Creates project schema and warehouse.
==============================================================================*/

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY
  COMMENT = 'DEMO: International bakery product classification showdown (Expires: 2026-03-20)';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared semantic views for Cortex Analyst and Intelligence agents';

CREATE WAREHOUSE IF NOT EXISTS SFE_GLAZE_AND_CLASSIFY_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Glaze & Classify compute (Expires: 2026-03-20)';

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;
