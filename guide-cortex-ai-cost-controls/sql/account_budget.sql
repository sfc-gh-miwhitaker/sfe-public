-- =============================================================================
-- ACCOUNT-LEVEL BUDGET
-- Run as: ACCOUNTADMIN (or a role with SNOWFLAKE.BUDGET_CREATOR database role)
-- Purpose: Create a budget object that monitors total account spend against a
--          threshold and triggers notifications or custom actions.
--
-- Budget objects are first-class Snowflake objects. They:
-- - Track credit consumption automatically against a defined limit
-- - Support threshold-based notifications (email, webhook)
-- - Can trigger custom actions (stored procedures) when thresholds are crossed
-- - Reset monthly (calendar month)
--
-- You can have exactly ONE account-level budget. For team/project budgets,
-- combine with tags (see tag_setup.sql) and custom enforcement (see
-- user_limits_ai_functions.sql for the pattern).
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Grant budget creation privilege (if not using ACCOUNTADMIN directly)
-- ─────────────────────────────────────────────────────────────────────────────

-- The BUDGET_CREATOR database role allows non-ACCOUNTADMIN roles to create budgets
-- GRANT DATABASE ROLE SNOWFLAKE.BUDGET_CREATOR TO ROLE cost_admin;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Create a schema for budget objects
-- ─────────────────────────────────────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS COST_GOVERNANCE;
CREATE SCHEMA IF NOT EXISTS COST_GOVERNANCE.BUDGETS;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Create the account-level budget
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET();

-- Set the monthly spending limit (in credits)
CALL COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET!SET_SPENDING_LIMIT(1000);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Add resources to monitor
-- Budget objects monitor specific resources. For an account-level AI budget,
-- you'll want to add the objects that drive AI spend.
-- ─────────────────────────────────────────────────────────────────────────────

-- Add the account itself (monitors all spend for the account)
CALL COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET!ADD_RESOURCE(
    SYSTEM$REFERENCE('ACCOUNT', CURRENT_ACCOUNT())
);

-- Or add specific warehouses that run AI workloads
-- CALL COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET!ADD_RESOURCE(
--     SYSTEM$REFERENCE('WAREHOUSE', 'AI_FUNCTIONS_WH')
-- );

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5: Configure email notifications at thresholds
-- ─────────────────────────────────────────────────────────────────────────────

-- Notify at 50%, 80%, and 100% of the budget
CALL COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET!SET_EMAIL_NOTIFICATIONS(
    'admin@yourcompany.com',
    ARRAY_CONSTRUCT(50, 80, 100)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 6: (Optional) Custom action at threshold
-- This is where you can implement "kill switches" — e.g., reduce CoCo limits
-- or revoke database roles when the budget is nearly exhausted.
-- ─────────────────────────────────────────────────────────────────────────────

-- Example: Create a procedure that reduces CoCo limits when budget hits 90%
CREATE OR REPLACE PROCEDURE COST_GOVERNANCE.BUDGETS.reduce_ai_limits()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    -- Reduce CoCo limits to 5 credits per user when budget is nearly exhausted
    ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 5;
    ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 5;
    ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 5;
    RETURN 'AI limits reduced due to budget threshold';
END;

-- Wire the custom action to trigger at 90%
-- CALL COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET!SET_CUSTOM_ACTION(
--     90,
--     'CALL COST_GOVERNANCE.BUDGETS.reduce_ai_limits()'
-- );

-- ─────────────────────────────────────────────────────────────────────────────
-- MONITORING: Check budget status
-- ─────────────────────────────────────────────────────────────────────────────

-- Current budget status
CALL COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET!GET_SPENDING_LIMIT();

-- View budget details from ACCOUNT_USAGE
SELECT
    budget_name,
    database_name,
    schema_name,
    credit_limit,
    current_month_spending
FROM SNOWFLAKE.ACCOUNT_USAGE.BUDGET_DETAILS
ORDER BY budget_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- TEARDOWN: Remove budget when no longer needed
-- ─────────────────────────────────────────────────────────────────────────────

-- DROP SNOWFLAKE.CORE.BUDGET COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET;
