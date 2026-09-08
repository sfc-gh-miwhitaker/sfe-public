/*=============================================================================
TEARDOWN ALL - Snowflake Streams CDC Workshop
Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08

WARNING: Deletes the project schema, its data, and its warehouse.
=============================================================================*/

USE ROLE SYSADMIN;

ALTER TASK IF EXISTS SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP.TASK_CONSUME_ORDER_CHANGES SUSPEND;

EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-streams-cdc-workshop/sql/99_cleanup/teardown.sql';
