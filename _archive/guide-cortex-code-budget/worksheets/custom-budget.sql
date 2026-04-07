/*==============================================================================
  WORKSHEET: Custom Budget — Setup & Inspection

  Purpose:    Create and configure a custom budget scoped to specific
              warehouses, databases, schemas, or tagged objects.
  Requires:   ACCOUNTADMIN for setup; SNOWFLAKE.BUDGET_VIEWER for inspection
  Important:  Custom budgets track WAREHOUSE credits, not AI credits.
              Cortex Code AI token costs appear only in the account budget
              under AI_SERVICES. Use custom budgets to cap warehouse compute
              for teams that use Cortex Code.
==============================================================================*/

/* ── SECTION 1: One-time account setup (ACCOUNTADMIN, run once ever) ───────
   Required before any custom budgets can be created.                        */

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.BUDGETS;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.BUDGETS TO APPLICATION SNOWFLAKE;


/* ── SECTION 2: Create a custom budget ────────────────────────────────────
   Change TEAM_BUDGET to a name that describes the scope.                    */

CREATE SNOWFLAKE.CORE.BUDGET SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET
    WITH BUDGET_ADMIN = CURRENT_ROLE();

-- Set monthly spending limit (credits)
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!SET_SPENDING_LIMIT(500);


/* ── SECTION 3a: Add resources by reference (immediate, no backfill) ───────
   ADD_RESOURCE adds a specific object directly.
   Mid-month adds do NOT backfill existing spend.
   Object can only belong to ONE budget.                                     */

-- Add a warehouse
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_RESOURCE(
    SYSTEM$REFERENCE('WAREHOUSE', 'TEAM_WH', 'SESSION', 'APPLYBUDGET')
);

-- Add a database (tracks all warehouses reading from it)
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_RESOURCE(
    SYSTEM$REFERENCE('DATABASE', 'MY_DB', 'SESSION', 'APPLYBUDGET')
);

-- Add a schema
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_RESOURCE(
    SYSTEM$REFERENCE('SCHEMA', 'MY_DB.MY_SCHEMA', 'SESSION', 'APPLYBUDGET')
);


/* ── SECTION 3b: Add resources by tag (recommended for multi-object) ───────
   ADD_RESOURCE_TAG adds ALL objects tagged with a given tag.
   Automatically includes new objects tagged in the future.
   Tagged objects can belong to multiple budgets (unlike ADD_RESOURCE).
   No backfill for existing spend on pre-existing objects.                   */

-- Create the tag (one-time)
CREATE TAG IF NOT EXISTS SNOWFLAKE_EXAMPLE.BUDGETS.BUDGET_TAG
  COMMENT = 'Assign to objects to include in a custom budget';

-- Tag the warehouse
ALTER WAREHOUSE TEAM_WH SET TAG SNOWFLAKE_EXAMPLE.BUDGETS.BUDGET_TAG = 'team_budget';

-- Find the tag reference for ADD_RESOURCE_TAG
SELECT SYSTEM$REFERENCE('TAG', 'SNOWFLAKE_EXAMPLE.BUDGETS.BUDGET_TAG', 'SESSION', 'APPLYBUDGET');

-- Add all tagged objects to the budget
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_RESOURCE_TAG(
    SYSTEM$REFERENCE('TAG', 'SNOWFLAKE_EXAMPLE.BUDGETS.BUDGET_TAG', 'SESSION', 'APPLYBUDGET')
);


/* ── SECTION 4: Add notifications ─────────────────────────────────────────
   Reuse integrations created in account-budget.sql SECTION 4/5.             */

-- Email at 80%
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
    'budgets_email_int',
    0.80,
    'Alert',
    'team-lead@example.com'
);

-- Slack at 90%
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_WEBHOOK_NOTIFICATION_INTEGRATION(
    'slack_budget_int',
    0.90,
    'Critical'
);

-- Verify
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!GET_NOTIFICATION_INTEGRATIONS();


/* ── SECTION 5: Set refresh tier ──────────────────────────────────────────
   Controls how frequently spend totals are recalculated.
   DEFAULT = hourly. FAST = 30-min (incurs additional serverless cost).      */

CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!SET_REFRESH_TIER('DEFAULT');
-- Use 'FAST' only if you need near-real-time enforcement


/* ── SECTION 6: Inspect current state ────────────────────────────────────
   Expected output from GET_SPENDING_HISTORY: rows with date + credits_used */

-- List all budgets in account
SHOW SNOWFLAKE.CORE.BUDGET INSTANCES IN ACCOUNT;

-- Get configuration
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!GET_CONFIGURATION();

-- Spending history this month
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!GET_SPENDING_HISTORY(
    TIME_LOWER_BOUND => DATE_TRUNC('month', CURRENT_DATE),
    TIME_UPPER_BOUND => CURRENT_TIMESTAMP
);

-- Resources tracked by this budget
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!GET_LINKED_RESOURCES();


/* ── SECTION 7: View tagged objects ────────────────────────────────────────
   Expected: all objects tagged with BUDGET_TAG (up to 2h latency).          */

SELECT OBJECT_DATABASE, OBJECT_SCHEMA, OBJECT_NAME, OBJECT_DOMAIN, TAG_VALUE
FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
WHERE TAG_DATABASE = 'SNOWFLAKE_EXAMPLE'
  AND TAG_SCHEMA = 'BUDGETS'
  AND TAG_NAME = 'BUDGET_TAG'
  AND TAG_RETIRED_ON IS NULL
ORDER BY OBJECT_DOMAIN, OBJECT_NAME;


/* ── SECTION 8: Delegate budget management ─────────────────────────────── */

-- Give a team lead admin rights on this specific budget only
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!SET_ADMIN_ROLE(
    SYSTEM$ROLE_REFERENCE('team_lead_role')
);


/* ── SECTION 9: Remove a resource or drop budget ─────────────────────────- */

-- Remove a specific resource
-- CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!REMOVE_RESOURCE(
--     SYSTEM$REFERENCE('WAREHOUSE', 'TEAM_WH', 'SESSION', 'APPLYBUDGET')
-- );

-- Drop the budget entirely
-- DROP SNOWFLAKE.CORE.BUDGET SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET;
