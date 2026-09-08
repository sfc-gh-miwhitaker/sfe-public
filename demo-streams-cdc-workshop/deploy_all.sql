/*=============================================================================
DEPLOY ALL - Snowflake Streams CDC Workshop
Pair-programmed by SE Community + Cortex Code | Expires: 2026-10-08

INSTRUCTIONS:
  1. Open Snowsight -> New Worksheet
  2. Paste this entire file
  3. Click Run All
  Expected runtime: about 2 minutes

WHAT GETS CREATED:
  Database:  SNOWFLAKE_EXAMPLE (shared, if not exists)
  Schema:    SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP
  Warehouse: SFE_STREAMS_CDC_WH
  Tables:    RAW_ORDERS, CURRENT_ORDERS, ORDER_CHANGE_AUDIT
  Stream:    RAW_ORDERS_STREAM
  Procedure: SP_CONSUME_ORDER_CHANGES
  Task:      TASK_CONSUME_ORDER_CHANGES (SUSPENDED)

AFTER DEPLOY:
  1. Run sql/04_workshop/01_first_change_batch.sql
  2. Run sql/98_validation/02_first_batch_pending_tests.sql
  3. Continue through the workshop scripts in numeric order

PREREQUISITES:
  - SYSADMIN, or a role able to create the project schema, warehouse, and task
  - Existing SFE_GIT_API_INTEGRATION for the public GitHub repository
  - EXECUTE TASK on the task owner role for the optional triggered-task exercise
=============================================================================*/

SELECT
  '2026-10-08'::DATE AS expiration_date,
  CURRENT_DATE() AS current_date,
  DATEDIFF('day', CURRENT_DATE(), '2026-10-08'::DATE) AS days_remaining,
  CASE
    WHEN DATEDIFF('day', CURRENT_DATE(), '2026-10-08'::DATE) < 0
      THEN 'EXPIRED - Code may use outdated syntax.'
    WHEN DATEDIFF('day', CURRENT_DATE(), '2026-10-08'::DATE) <= 7
      THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-10-08'::DATE) || ' days remaining'
    ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-10-08'::DATE) || ' days remaining'
  END AS demo_status;

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'Shared database for SE demo projects';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository integrations';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Public SE demos monorepo';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-streams-cdc-workshop/sql/01_setup/01_create_schema.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-streams-cdc-workshop/sql/02_data/01_create_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-streams-cdc-workshop/sql/02_data/02_load_baseline.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-streams-cdc-workshop/sql/03_processing/01_create_stream.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-streams-cdc-workshop/sql/03_processing/02_create_consumer.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-streams-cdc-workshop/sql/03_processing/03_create_triggered_task.sql';

SELECT
  'Snowflake Streams CDC Workshop' AS demo,
  (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP.RAW_ORDERS) AS source_rows,
  (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP.CURRENT_ORDERS) AS target_rows,
  SYSTEM$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.STREAMS_CDC_WORKSHOP.RAW_ORDERS_STREAM') AS stream_has_data,
  'Run sql/04_workshop/01_first_change_batch.sql' AS next_step;
