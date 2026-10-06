/*
  guide-shopify-multistore-snowflake — sql/native/04_schedule.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    The daily schedule, created suspended.

  SAFETY
    CREATE TASK leaves the task suspended. Resume it only after the pilot store
    has passed every qualification gate. The task timeout and the warehouse
    STATEMENT_TIMEOUT_IN_SECONDS are both two hours; the lower non-zero setting
    wins, so keep them aligned if you change either.

  RUN AS      SHOPIFY_PIPELINE_RL
  SOURCE      https://docs.snowflake.com/en/user-guide/tasks-intro
*/

USE ROLE SHOPIFY_PIPELINE_RL;
USE WAREHOUSE SHOPIFY_PIPELINE_WH;

CREATE TASK IF NOT EXISTS SHOPIFY_NATIVE.CONTROL.DAILY_SHOPIFY_PULL
  WAREHOUSE = SHOPIFY_PIPELINE_WH
  SCHEDULE = 'USING CRON 0 2 * * * UTC'
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3
  USER_TASK_TIMEOUT_MS = 7200000
  COMMENT = 'Daily deterministic Shopify Bulk API pull; resume only after qualification'
AS
  CALL SHOPIFY_NATIVE.CONTROL.PULL_ALL_STORES();

-- Promotion gate. Run only after inspecting QUALIFICATION_RESULTS.
-- EXECUTE TASK proves the scheduled owner-role path before the schedule runs.
--
-- UPDATE SHOPIFY_CONTROL.META.STORE_REGISTRY SET IS_ACTIVE = TRUE
-- WHERE STORE_KEY = 'STORE_ALPHA' AND QUALIFICATION_STATUS = 'PASSED';
--
-- EXECUTE TASK SHOPIFY_NATIVE.CONTROL.DAILY_SHOPIFY_PULL;
-- ALTER TASK SHOPIFY_NATIVE.CONTROL.DAILY_SHOPIFY_PULL RESUME;

SHOW TASKS LIKE 'DAILY_SHOPIFY_PULL' IN SCHEMA SHOPIFY_NATIVE.CONTROL;
