/*=============================================================================
  03_processing/03_create_triggered_task.sql
  Snowflake Streams CDC Workshop - Optional Triggered Task
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_STREAMS_CDC_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;

CREATE OR REPLACE TASK TASK_CONSUME_ORDER_CHANGES
  WAREHOUSE = SFE_STREAMS_CDC_WH
  USER_TASK_TIMEOUT_MS = 60000
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3
  COMMENT = 'DEMO: Triggered CDC consumer; ships suspended (Expires: 2026-10-08)'
  WHEN SYSTEM$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP.RAW_ORDERS_STREAM')
AS
  CALL SP_CONSUME_ORDER_CHANGES();
