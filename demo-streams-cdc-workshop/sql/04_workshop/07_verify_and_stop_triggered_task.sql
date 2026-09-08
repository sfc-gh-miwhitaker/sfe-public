/*=============================================================================
  04_workshop/07_verify_and_stop_triggered_task.sql
  Optional Exercise - Verify Triggered Execution and Stop Automation
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_STREAMS_CDC_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;

SELECT
  NAME,
  STATE,
  SCHEDULED_FROM,
  SCHEDULED_TIME,
  COMPLETED_TIME,
  ERROR_CODE,
  ERROR_MESSAGE
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.TASK_HISTORY(
  SCHEDULED_TIME_RANGE_START => DATEADD('minute', -10, CURRENT_TIMESTAMP()),
  SCHEDULED_TIME_RANGE_END => CURRENT_TIMESTAMP(),
  RESULT_LIMIT => 20,
  TASK_NAME => 'TASK_CONSUME_ORDER_CHANGES',
  DATABASE_NAME => 'SNOWFLAKE_EXAMPLE',
  SCHEMA_NAME => 'STREAMS_CDC_WORKSHOP'
))
ORDER BY SCHEDULED_TIME DESC;

ALTER TASK TASK_CONSUME_ORDER_CHANGES SUSPEND;

SELECT
  (SELECT COUNT(*) FROM RAW_ORDERS) AS source_rows,
  (SELECT COUNT(*) FROM CURRENT_ORDERS) AS target_rows,
  (SELECT COUNT(*) FROM ORDER_CHANGE_AUDIT) AS cumulative_audit_rows,
  SYSTEM$STREAM_HAS_DATA('RAW_ORDERS_STREAM') AS stream_has_data;
