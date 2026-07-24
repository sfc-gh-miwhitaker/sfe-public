/*==============================================================================
04_BUDGET — Account AI budget object (illustrative)
Cortex AI Cost Controls demo | Expires: 2026-07-24

Creates a custom budget and sets a monthly spending limit + notification
threshold. Wrapped in an exception-guarded block so that budget privilege
quirks never break the one-command deploy — if the step is skipped, the
Anomaly page falls back to reading the built-in SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET.

NOTE: Email notifications require VERIFIED recipient addresses and a notification
integration; that step is intentionally left commented. A custom budget scoped
specifically to AI spend requires linking resources/tags — see the guide. This
object demonstrates the pattern (create → set limit → notify threshold).
==============================================================================*/

USE ROLE ACCOUNTADMIN;  -- budget instance creation needs elevated privileges
USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS;
USE WAREHOUSE SFE_CORTEX_AI_COST_CONTROLS_WH;

DECLARE
    v_status STRING;
BEGIN
    CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS AI_BUDGET();
    CALL AI_BUDGET!SET_SPENDING_LIMIT(1000);          -- monthly credit limit
    CALL AI_BUDGET!SET_NOTIFICATION_THRESHOLD(80);    -- notify at 80% projected
    -- Email notifications (requires verified addresses + integration):
    -- CALL AI_BUDGET!SET_EMAIL_NOTIFICATIONS('admin@yourcompany.com');
    v_status := 'AI_BUDGET created; spending limit 1000, notify at 80%';
    RETURN :v_status;
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Budget step skipped (non-fatal): ' || SQLERRM
               || ' — Anomaly page will use SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET instead.';
END;
