/*=============================================================================
  01_setup/01_create_schema.sql
  Snowflake Streams CDC Workshop - Schema and Warehouse
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SFE_STREAMS_CDC_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'DEMO: Streams CDC workshop compute (Expires: 2026-10-08)';

USE WAREHOUSE SFE_STREAMS_CDC_WH;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'Shared database for SE demo projects';

CREATE OR REPLACE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP
  COMMENT = 'DEMO: Transactional Streams CDC workshop (Expires: 2026-10-08)';

USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;
