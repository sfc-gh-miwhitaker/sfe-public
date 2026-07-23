-- =============================================================================
-- CORTEX CODE — NATIVE PER-USER CREDIT LIMITS
-- Run as: ACCOUNTADMIN
-- Purpose: Set daily credit usage caps for Cortex Code (CoCo) across all 3 surfaces.
--
-- This is the ONLY Cortex service with native per-user limits built into the platform.
-- No custom tasks, no stored procedures — just ALTER ACCOUNT/USER and you're done.
--
-- How it works:
-- - Rolling 24-hour window tracks estimated credit usage per user
-- - When the limit is reached, access to that surface is blocked until usage rolls off
-- - User-level settings override account-level settings
--
-- Values:
--   -1  = No limit (default)
--    0  = Completely disabled (user cannot use this surface at all)
--   >0  = Daily credit cap (access blocked when estimated usage reaches this value)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- OPTION A: Set account-wide defaults (applies to all users who don't have
-- a user-level override)
-- ─────────────────────────────────────────────────────────────────────────────

-- CoCo CLI (terminal / VS Code / Cursor)
ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;

-- CoCo Desktop (native IDE application)
ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;

-- CoCo in Snowsight (web UI)
ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;

-- ─────────────────────────────────────────────────────────────────────────────
-- OPTION B: Override for a specific user (takes precedence over account-level)
-- ─────────────────────────────────────────────────────────────────────────────

-- Give a power user a higher limit
ALTER USER power_user SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;
ALTER USER power_user SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;

-- Block a user from a specific surface entirely
ALTER USER restricted_user SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 0;

-- ─────────────────────────────────────────────────────────────────────────────
-- REMOVE LIMITS (restore to unlimited)
-- ─────────────────────────────────────────────────────────────────────────────

-- Remove account-level limits
ALTER ACCOUNT UNSET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER;
ALTER ACCOUNT UNSET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER;
ALTER ACCOUNT UNSET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER;

-- Remove user-level override (user falls back to account-level setting)
ALTER USER power_user UNSET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER;

-- ─────────────────────────────────────────────────────────────────────────────
-- AUDIT: Which users have custom limits set?
-- ─────────────────────────────────────────────────────────────────────────────

EXECUTE IMMEDIATE $$
DECLARE
    current_user STRING;
    rs_users RESULTSET;
    res RESULTSET;
BEGIN
    CREATE OR REPLACE TEMPORARY TABLE _param_overrides (
        user_name STRING,
        surface STRING,
        param_value STRING
    );

    SHOW USERS;
    rs_users := (SELECT "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));

    FOR record IN rs_users DO
        current_user := record."name";

        -- Check CLI limit
        EXECUTE IMMEDIATE
            'SHOW PARAMETERS LIKE ''CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER'' IN USER "' || :current_user || '"';
        INSERT INTO _param_overrides (user_name, surface, param_value)
            SELECT :current_user, 'CLI', "value"
            FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
            WHERE "level" = 'USER';

        -- Check Desktop limit
        EXECUTE IMMEDIATE
            'SHOW PARAMETERS LIKE ''CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER'' IN USER "' || :current_user || '"';
        INSERT INTO _param_overrides (user_name, surface, param_value)
            SELECT :current_user, 'Desktop', "value"
            FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
            WHERE "level" = 'USER';

        -- Check Snowsight limit
        EXECUTE IMMEDIATE
            'SHOW PARAMETERS LIKE ''CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER'' IN USER "' || :current_user || '"';
        INSERT INTO _param_overrides (user_name, surface, param_value)
            SELECT :current_user, 'Snowsight', "value"
            FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
            WHERE "level" = 'USER';
    END FOR;

    res := (SELECT user_name, surface, param_value FROM _param_overrides ORDER BY user_name, surface);
    RETURN TABLE(res);
END;
$$;
