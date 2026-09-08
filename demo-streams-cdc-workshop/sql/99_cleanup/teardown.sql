/*=============================================================================
  99_cleanup/teardown.sql
  Snowflake Streams CDC Workshop - Project Cleanup
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;

ALTER TASK IF EXISTS SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP.TASK_CONSUME_ORDER_CHANGES SUSPEND;
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP CASCADE;
DROP WAREHOUSE IF EXISTS SFE_STREAMS_CDC_WH;

SELECT
  'Teardown complete. Shared database and Git repository objects were preserved.' AS status;
