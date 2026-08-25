-- ============================================================================
-- Per-User Quota Setup Example
-- Demonstrates native AI cost governance using SNOWFLAKE.CORE.QUOTA.
-- Pair-programmed by SE Community + Cortex Code
-- ============================================================================
-- IMPORTANT: Requires ACCOUNTADMIN or a role with QUOTA_CREATOR database role.
-- This script is idempotent and exception-guarded for demo safety.

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS;

-- ---------------------------------------------------------------------------
-- Step 1: Create the quota object
-- ---------------------------------------------------------------------------
BEGIN
    CREATE SNOWFLAKE.CORE.QUOTA IF NOT EXISTS AI_COST_QUOTA();
EXCEPTION
    WHEN OTHER THEN
        -- Quota creation requires specific privileges; skip gracefully
        RETURN 'SKIP: Could not create quota (missing QUOTA_CREATOR role). ' || SQLERRM;
END;

-- ---------------------------------------------------------------------------
-- Step 2: Add monitored AI domains
-- Each domain tracks credits independently; all roll into the per-user limit.
-- ---------------------------------------------------------------------------
BEGIN
    CALL AI_COST_QUOTA!ADD_SHARED_RESOURCE('AI FUNCTION');
    CALL AI_COST_QUOTA!ADD_SHARED_RESOURCE('CORTEX AGENT');
    CALL AI_COST_QUOTA!ADD_SHARED_RESOURCE('SNOWFLAKE COWORK');
    CALL AI_COST_QUOTA!ADD_SHARED_RESOURCE('CORTEX CODE');
EXCEPTION
    WHEN OTHER THEN
        RETURN 'SKIP: Could not configure quota domains. ' || SQLERRM;
END;

-- ---------------------------------------------------------------------------
-- Step 3: Set per-user spending limits
-- All users in scope share the same limit (evaluated independently per user).
-- ---------------------------------------------------------------------------
BEGIN
    -- Monthly: 500 AI credits per user
    CALL AI_COST_QUOTA!SET_PER_USER_LIMIT(500);

    -- Daily: 50 AI credits per user (resets at UTC midnight)
    CALL AI_COST_QUOTA!SET_PER_USER_LIMIT(50, 'DAILY');
EXCEPTION
    WHEN OTHER THEN
        RETURN 'SKIP: Could not set quota limits. ' || SQLERRM;
END;

-- ---------------------------------------------------------------------------
-- Step 4: Enable block enforcement
-- Users are auto-blocked within minutes of hitting their limit.
-- Blocks release automatically at cycle reset (UTC midnight or month start).
-- Second argument: TRUE = notify the user via email when blocked.
-- ---------------------------------------------------------------------------
BEGIN
    CALL AI_COST_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE, TRUE);
EXCEPTION
    WHEN OTHER THEN
        RETURN 'SKIP: Could not enable block enforcement. ' || SQLERRM;
END;

-- ---------------------------------------------------------------------------
-- Step 5: Configure notification thresholds
-- Projected spend triggers early warning before limits are breached.
-- ---------------------------------------------------------------------------
BEGIN
    -- Alert at 80% projected monthly spend (notify the user directly)
    CALL AI_COST_QUOTA!ADD_NOTIFICATION_THRESHOLD(80, 'PROJECTED', TRUE, 'MONTHLY');

    -- Alert at 90% actual daily spend
    CALL AI_COST_QUOTA!ADD_NOTIFICATION_THRESHOLD(90, 'ACTUAL', TRUE, 'DAILY');
EXCEPTION
    WHEN OTHER THEN
        RETURN 'SKIP: Could not set notification thresholds. ' || SQLERRM;
END;

-- ---------------------------------------------------------------------------
-- Step 6: (Optional) Scope to specific users via tags
-- By default, the quota monitors ALL users. Uncomment to scope by tag.
-- ---------------------------------------------------------------------------
/*
-- Scope to users tagged with cost_center = 'analytics'
CALL AI_COST_QUOTA!SET_USER_TAGS(
    [
        [(SELECT SYSTEM$REFERENCE('TAG', 'SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'analytics']
    ],
    'UNION'
);
*/

-- ---------------------------------------------------------------------------
-- Verify configuration
-- ---------------------------------------------------------------------------
CALL AI_COST_QUOTA!GET_CONFIG();
