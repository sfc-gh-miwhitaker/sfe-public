/*=============================================================================
  98_validation/03_object_inventory.sql
  Snowflake Streams CDC Workshop - Object and Metadata Inventory
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08
=============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_STREAMS_CDC_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP;

SHOW TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP
  ->> SELECT
        "name" AS object_name,
        "kind" AS object_type,
        "comment" AS object_comment
      FROM $1
      ORDER BY object_name;

SHOW STREAMS IN SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP
  ->> SELECT
        "name" AS object_name,
        'STREAM' AS object_type,
        "mode" AS stream_mode,
        "stale" AS is_stale,
        "stale_after" AS stale_after,
        "comment" AS object_comment
      FROM $1;

SHOW TASKS LIKE 'TASK_CONSUME_ORDER_CHANGES'
  IN SCHEMA SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP
  ->> SELECT
        "name" AS object_name,
        "state" AS task_state,
        "schedule" AS task_schedule,
        "condition" AS trigger_condition,
        "comment" AS object_comment
      FROM $1;
