/*=============================================================================
  04_workshop/05_retention_and_staleness.sql
  Exercise 5 - Inspect Retention and the Stream Staleness Deadline
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_STREAMS_CDC_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;

SHOW STREAMS LIKE 'RAW_ORDERS_STREAM' IN SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP
  ->> SELECT
        "name" AS stream_name,
        "table_name" AS source_table,
        "mode" AS stream_mode,
        "stale" AS is_stale,
        "stale_after" AS stale_after
      FROM $1;

SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS'
  IN TABLE SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP.RAW_ORDERS
  ->> SELECT
        "key" AS parameter_name,
        "value" AS parameter_value,
        "level" AS parameter_level
      FROM $1;

SHOW PARAMETERS LIKE 'MAX_DATA_EXTENSION_TIME_IN_DAYS' IN ACCOUNT
  ->> SELECT
        "key" AS parameter_name,
        "value" AS parameter_value,
        "level" AS parameter_level
      FROM $1;
