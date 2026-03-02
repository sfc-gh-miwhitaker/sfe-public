/*==============================================================================
SETUP - OpenAI Data Engineering
Creates schema, warehouse, and session context.
==============================================================================*/

USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SFE_OPENAI_DATA_ENG_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: OpenAI data engineering compute (Expires: 2026-03-28)';

USE WAREHOUSE SFE_OPENAI_DATA_ENG_WH;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG
  COMMENT = 'DEMO: OpenAI API data engineering patterns (Expires: 2026-03-28)';

USE SCHEMA SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG;

CREATE OR REPLACE FILE FORMAT openai_jsonl_ff
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE
  COMMENT = 'DEMO: JSON format for OpenAI API response files (Expires: 2026-03-28)';

CREATE OR REPLACE STAGE openai_raw_stage
  FILE_FORMAT = openai_jsonl_ff
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'DEMO: Landing zone for OpenAI API export files (Expires: 2026-03-28)';
