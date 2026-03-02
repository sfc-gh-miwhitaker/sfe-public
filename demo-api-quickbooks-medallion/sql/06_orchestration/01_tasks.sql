/*==============================================================================
06_ORCHESTRATION / 01_TASKS
Only ONE task is needed -- the rest of the pipeline is fully declarative:
  - Dynamic tables cascade automatically (Silver -> Cortex -> Gold)
  - DMFs run on their own cron schedule (serverless compute)

This task calls the Python stored procedure to fetch new data from QBO.
Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- FETCH_QBO_ENTITIES_TASK
-- Hourly incremental fetch of all 7 QBO entities.
-- Replace '<YOUR_REALM_ID>' with your QuickBooks Company ID.
--
-- TEACHING NOTE: This is the only orchestration needed. Once Bronze RAW_
-- tables are populated, the entire downstream pipeline is declarative:
--   RAW_ tables → STG_ dynamic tables (TARGET_LAG = 1 hour)
--     → Cortex enrichment dynamic tables (TARGET_LAG = DOWNSTREAM)
--       → Gold dynamic tables (TARGET_LAG = DOWNSTREAM)
-- DMFs evaluate on their own cron schedule against Silver tables.
-------------------------------------------------------------------------------
CREATE OR REPLACE TASK FETCH_QBO_ENTITIES_TASK
    WAREHOUSE = SFE_QB_API_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'
    COMMENT = 'DEMO: Hourly incremental fetch from QBO API (Expires: 2026-03-29)'
AS
    CALL FETCH_ALL_QBO_ENTITIES('<YOUR_REALM_ID>', FALSE);

-- Start the task (paused by default)
-- ALTER TASK FETCH_QBO_ENTITIES_TASK RESUME;

-- To run once immediately for testing:
-- EXECUTE TASK FETCH_QBO_ENTITIES_TASK;

-- To check task history:
-- SELECT *
-- FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
--     TASK_NAME => 'FETCH_QBO_ENTITIES_TASK',
--     SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP())
-- ))
-- ORDER BY SCHEDULED_TIME DESC;
