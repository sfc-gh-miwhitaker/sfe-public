/*==============================================================================
TABLES - OpenAI Data Engineering
Raw landing tables for three OpenAI data formats.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG;

CREATE OR REPLACE TABLE RAW_CHAT_COMPLETIONS (
  loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  source_file VARCHAR,
  raw         VARIANT
) COMMENT = 'DEMO: Raw OpenAI Chat Completions API responses (Expires: 2026-03-28)';

CREATE OR REPLACE TABLE RAW_BATCH_OUTPUTS (
  loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  source_file VARCHAR,
  raw         VARIANT
) COMMENT = 'DEMO: Raw OpenAI Batch API output records (Expires: 2026-03-28)';

CREATE OR REPLACE TABLE RAW_USAGE_BUCKETS (
  loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  source_file VARCHAR,
  raw         VARIANT
) COMMENT = 'DEMO: Raw OpenAI Usage API bucket records (Expires: 2026-03-28)';
