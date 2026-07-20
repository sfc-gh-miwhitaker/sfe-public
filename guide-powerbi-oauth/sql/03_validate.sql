/*==============================================================================
  GUIDE: Power BI + Snowflake OAuth
  Step 3 of 3 — Validation Queries
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-19
==============================================================================*/

-- Run these AFTER attempting your first Power BI OAuth connection.

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- 1. Confirm security integration is active
-- ============================================================
DESC SECURITY INTEGRATION powerbi;

-- ============================================================
-- 2. Recent Power BI login attempts (last 1 hour)
-- ============================================================
SELECT
    event_timestamp,
    user_name,
    client_application_id,
    first_authentication_factor,
    is_success,
    error_message
FROM TABLE(information_schema.login_history(
    DATEADD('hours', -1, CURRENT_TIMESTAMP()),
    CURRENT_TIMESTAMP()
))
WHERE client_application_id ILIKE '%power%'
   OR first_authentication_factor = 'OAUTH_ACCESS_TOKEN'
ORDER BY event_timestamp DESC;

-- Success indicator: FIRST_AUTHENTICATION_FACTOR = 'OAUTH_ACCESS_TOKEN'

-- ============================================================
-- 3. Get detailed error for a failed login (use UUID from error message)
-- ============================================================
-- SELECT SYSTEM$GET_LOGIN_FAILURE_DETAILS('<uuid-from-error>');

-- ============================================================
-- 4. Validate an OAuth token directly
-- ============================================================
-- SELECT SYSTEM$VERIFY_EXTERNAL_OAUTH_TOKEN('<paste_token_here>');

-- ============================================================
-- 5. Confirm user's role grants look correct
-- ============================================================
-- SHOW GRANTS TO USER <username>;
