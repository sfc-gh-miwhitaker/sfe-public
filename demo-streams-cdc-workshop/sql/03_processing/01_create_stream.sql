/*=============================================================================
  03_processing/01_create_stream.sql
  Snowflake Streams CDC Workshop - Standard Stream
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_STREAMS_CDC_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;

CREATE OR REPLACE STREAM RAW_ORDERS_STREAM
  ON TABLE RAW_ORDERS
  APPEND_ONLY = FALSE
  COMMENT = 'DEMO: Standard Stream tracking inserts, updates, and deletes (Expires: 2026-10-08)';
