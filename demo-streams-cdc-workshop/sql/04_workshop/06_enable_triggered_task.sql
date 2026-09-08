/*=============================================================================
  04_workshop/06_enable_triggered_task.sql
  Optional Exercise - Enable the Triggered Task and Generate a Change
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_STREAMS_CDC_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;

ALTER TASK TASK_CONSUME_ORDER_CHANGES RESUME;

INSERT INTO RAW_ORDERS (
  ORDER_ID,
  CUSTOMER_ID,
  ORDER_STATUS,
  ORDER_TOTAL,
  ORDER_TS,
  UPDATED_AT
)
VALUES
  (1007, 507, 'PENDING', 77.70, '2026-09-08 12:00:00', '2026-09-08 12:00:00');

SELECT
  'Wait up to 30 seconds, then run 07_verify_and_stop_triggered_task.sql.' AS next_step;
