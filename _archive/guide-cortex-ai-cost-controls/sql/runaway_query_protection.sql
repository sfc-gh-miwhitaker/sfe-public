-- =============================================================================
-- RUNAWAY QUERY PROTECTION — AI FUNCTIONS
-- Run as: ACCOUNTADMIN
-- Purpose: Detect and cancel AI Functions queries that exceed a credit threshold
--          while they are still running.
--
-- How it works:
-- CORTEX_AI_FUNCTIONS_USAGE_HISTORY tracks queries with IS_COMPLETED = FALSE
-- when they are still executing. This procedure finds running queries that have
-- already consumed more credits than the defined threshold and cancels them.
--
-- CRITICAL CAVEAT: This view has up to 60 minutes of latency (data may appear
-- as quickly as 10 minutes, but the maximum is 60). This means:
-- - A query that has been running for 5 minutes will NOT appear in the view yet
-- - By the time a runaway query appears, it may have consumed significantly
--   more credits than what the view shows
-- - This is a safety net, not a real-time circuit breaker
--
-- For time-based protection (stops ALL long queries, not just expensive ones),
-- use STATEMENT_TIMEOUT_IN_SECONDS on the warehouse instead.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS COST_GOVERNANCE;
CREATE SCHEMA IF NOT EXISTS COST_GOVERNANCE.ENFORCEMENT;
USE SCHEMA COST_GOVERNANCE.ENFORCEMENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- Configuration: Set your credit threshold for cancellation
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS runaway_query_config (
    config_key   VARCHAR PRIMARY KEY,
    config_value NUMBER(10,2)
);

-- Cancel any single query consuming more than this many credits.
-- MERGE is Snowflake's upsert (Snowflake has no Postgres-style ON CONFLICT).
MERGE INTO runaway_query_config AS t
USING (SELECT 'credit_threshold' AS config_key, 5.00 AS config_value) AS s
    ON t.config_key = s.config_key
WHEN MATCHED THEN UPDATE SET t.config_value = s.config_value
WHEN NOT MATCHED THEN INSERT (config_key, config_value) VALUES (s.config_key, s.config_value);

-- ─────────────────────────────────────────────────────────────────────────────
-- The cancellation procedure
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE cancel_runaway_ai_queries()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
DECLARE
    v_threshold NUMBER(10,2);
    v_cancelled INTEGER DEFAULT 0;
BEGIN
    -- Get the configured threshold
    SELECT config_value INTO :v_threshold
    FROM COST_GOVERNANCE.ENFORCEMENT.runaway_query_config
    WHERE config_key = 'credit_threshold';

    -- Find running queries over the threshold
    FOR runaway IN (
        SELECT query_id, credits, function_name, model_name, user_id
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY
        WHERE is_completed = FALSE
          AND credits >= :v_threshold
    ) DO
        -- Attempt to cancel the query
        SELECT SYSTEM$CANCEL_QUERY(:runaway.query_id);
        v_cancelled := v_cancelled + 1;

        -- Log the cancellation
        INSERT INTO COST_GOVERNANCE.ENFORCEMENT.runaway_query_log (
            cancelled_at, query_id, credits_at_cancellation, function_name, model_name, user_id
        )
        VALUES (
            CURRENT_TIMESTAMP(),
            :runaway.query_id,
            :runaway.credits,
            :runaway.function_name,
            :runaway.model_name,
            :runaway.user_id
        );
    END FOR;

    RETURN 'Cancelled ' || :v_cancelled || ' runaway queries';
END;

-- ─────────────────────────────────────────────────────────────────────────────
-- Cancellation log table (for audit trail)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS runaway_query_log (
    cancelled_at          TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    query_id              VARCHAR,
    credits_at_cancellation NUMBER(10,2),
    function_name         VARCHAR,
    model_name            VARCHAR,
    user_id               NUMBER
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Schedule: Run every 10 minutes (matches the minimum view refresh cadence)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE TASK cancel_runaway_ai_queries_task
  WAREHOUSE = '<your_warehouse>'
  SCHEDULE = '10 MINUTE'
  COMMENT = 'Cancels AI Functions queries exceeding credit threshold (safety net with 10-60 min latency)'
AS
  CALL COST_GOVERNANCE.ENFORCEMENT.cancel_runaway_ai_queries();

ALTER TASK cancel_runaway_ai_queries_task RESUME;

-- ─────────────────────────────────────────────────────────────────────────────
-- ALSO RECOMMENDED: Time-based warehouse timeout (complements credit-based)
-- This fires immediately — no latency. Use both together.
-- ─────────────────────────────────────────────────────────────────────────────

-- Set a 30-minute hard timeout on the warehouse running AI Functions
-- ALTER WAREHOUSE ai_functions_wh SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;

-- ─────────────────────────────────────────────────────────────────────────────
-- MONITORING: Review recent cancellations
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    cancelled_at,
    query_id,
    credits_at_cancellation,
    function_name,
    model_name,
    user_id
FROM COST_GOVERNANCE.ENFORCEMENT.runaway_query_log
ORDER BY cancelled_at DESC
LIMIT 20;
