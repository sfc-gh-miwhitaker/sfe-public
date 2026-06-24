-- =============================================================================
-- AI FUNCTIONS — DIY PER-USER CREDIT LIMITS
-- Run as: ACCOUNTADMIN
-- Purpose: Build a custom enforcement loop that monitors per-user AI Functions
--          spend and revokes/restores the AI_FUNCTIONS_USER database role.
--
-- There is NO native per-user limit for AI Functions. This is the full DIY pattern:
--   1. A limits table (defines each user's credit cap)
--   2. A stored procedure (checks usage vs limit, revokes or restores access)
--   3. A task (runs the procedure on a schedule)
--
-- The AI_FUNCTIONS_USER database role (GA April 2026) gates access to all AI SQL
-- functions (AI_CLASSIFY, AI_COMPLETE, AI_EXTRACT, AI_FILTER, AI_SENTIMENT, etc.)
-- independently of the broader CORTEX_USER role.
--
-- Latency caveat: CORTEX_AI_FUNCTIONS_USAGE_HISTORY has up to 45-minute latency.
-- This means a user could exceed their limit by up to 45 minutes of spend before
-- the task detects and revokes access.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Change these to your governance schema
CREATE DATABASE IF NOT EXISTS COST_GOVERNANCE;
CREATE SCHEMA IF NOT EXISTS COST_GOVERNANCE.ENFORCEMENT;
USE SCHEMA COST_GOVERNANCE.ENFORCEMENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Create the limits table
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ai_function_user_limits (
    user_name         VARCHAR NOT NULL,
    daily_credit_limit NUMBER(10,2) NOT NULL,
    is_revoked        BOOLEAN DEFAULT FALSE,
    revoked_at        TIMESTAMP_LTZ,
    restored_at       TIMESTAMP_LTZ,
    CONSTRAINT pk_user_limits PRIMARY KEY (user_name)
);

-- Define limits for each user (adjust as needed).
-- MERGE is Snowflake's upsert (Snowflake has no Postgres-style ON CONFLICT).
MERGE INTO ai_function_user_limits AS t
USING (
    SELECT column1 AS user_name, column2 AS daily_credit_limit
    FROM VALUES
        ('ALICE', 10.00),
        ('BOB', 5.00),
        ('CAROL', 20.00)
) AS s
    ON t.user_name = s.user_name
WHEN MATCHED THEN UPDATE SET t.daily_credit_limit = s.daily_credit_limit
WHEN NOT MATCHED THEN INSERT (user_name, daily_credit_limit)
    VALUES (s.user_name, s.daily_credit_limit);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Create the enforcement procedure
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE enforce_ai_function_limits()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
DECLARE
    v_role STRING;
BEGIN
    -- Get each user's spend in the last 24 hours.
    -- CORTEX_AI_FUNCTIONS_USAGE_HISTORY exposes USER_ID (not USER_NAME), so we
    -- map it through ACCOUNT_USAGE.USERS to match the limits table by name.
    CREATE OR REPLACE TEMPORARY TABLE _current_usage AS
    SELECT
        lim.user_name,
        COALESCE(SUM(h.credits), 0) AS credits_last_24h
    FROM ai_function_user_limits lim
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
        ON u.name = lim.user_name AND u.deleted_on IS NULL
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY h
        ON h.user_id = u.user_id
       AND h.start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
    GROUP BY lim.user_name;

    -- REVOKE: Users over their limit who haven't been revoked yet.
    -- The target of REVOKE must be a literal role identifier, so resolve the
    -- user's default role into a variable first, then inject via IDENTIFIER().
    FOR overbudget IN (
        SELECT cu.user_name
        FROM _current_usage cu
        JOIN ai_function_user_limits lim ON cu.user_name = lim.user_name
        WHERE cu.credits_last_24h >= lim.daily_credit_limit
          AND lim.is_revoked = FALSE
    ) DO
        SELECT default_role INTO :v_role
        FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
        WHERE name = :overbudget.user_name AND deleted_on IS NULL
        ORDER BY created_on DESC
        LIMIT 1;

        IF (v_role IS NOT NULL) THEN
            EXECUTE IMMEDIATE
                'REVOKE DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER FROM ROLE IDENTIFIER(''' || :v_role || ''')';
            UPDATE ai_function_user_limits
                SET is_revoked = TRUE, revoked_at = CURRENT_TIMESTAMP()
                WHERE user_name = :overbudget.user_name;
        END IF;
    END FOR;

    -- RESTORE: Users under their limit who were previously revoked
    FOR underbudget IN (
        SELECT cu.user_name
        FROM _current_usage cu
        JOIN ai_function_user_limits lim ON cu.user_name = lim.user_name
        WHERE cu.credits_last_24h < lim.daily_credit_limit
          AND lim.is_revoked = TRUE
    ) DO
        SELECT default_role INTO :v_role
        FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
        WHERE name = :underbudget.user_name AND deleted_on IS NULL
        ORDER BY created_on DESC
        LIMIT 1;

        IF (v_role IS NOT NULL) THEN
            EXECUTE IMMEDIATE
                'GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE IDENTIFIER(''' || :v_role || ''')';
            UPDATE ai_function_user_limits
                SET is_revoked = FALSE, restored_at = CURRENT_TIMESTAMP()
                WHERE user_name = :underbudget.user_name;
        END IF;
    END FOR;

    RETURN 'Enforcement check complete';
END;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Schedule a task to run the procedure
-- (every 15 minutes is a reasonable cadence given the view's latency)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE TASK enforce_ai_function_limits_task
  WAREHOUSE = '<your_warehouse>'
  SCHEDULE = '15 MINUTE'
  COMMENT = 'Checks AI Functions usage against per-user limits and revokes/restores AI_FUNCTIONS_USER'
AS
  CALL COST_GOVERNANCE.ENFORCEMENT.enforce_ai_function_limits();

-- Start the task (tasks are created in a suspended state)
ALTER TASK enforce_ai_function_limits_task RESUME;

-- ─────────────────────────────────────────────────────────────────────────────
-- MONITORING: Check who's been revoked
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    user_name,
    daily_credit_limit,
    is_revoked,
    revoked_at,
    restored_at
FROM COST_GOVERNANCE.ENFORCEMENT.ai_function_user_limits
ORDER BY is_revoked DESC, user_name;
