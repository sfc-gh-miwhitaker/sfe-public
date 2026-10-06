-- ============================================================
-- Resource Monitor Setup
-- ============================================================
-- This file covers:
--   1. Creating a warehouse-level resource monitor (recommended starting point)
--   2. Creating an account-level resource monitor
--   3. Assigning warehouses to a monitor
--   4. Modifying an existing monitor (safely — TRIGGERS is not additive)
--   5. Adding non-admin users to notification lists
--   6. Verification queries
--   7. Removing or resetting monitors
--
-- Required role: ACCOUNTADMIN
-- IMPORTANT: Resource monitors work for WAREHOUSES ONLY.
-- They do not track or stop AI services, serverless tasks, auto-clustering,
-- or any compute outside of virtual warehouses.
-- For AI services spend governance, use the Budget object (budget_setup.sql).
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ── STEP 1: CHECK EXISTING MONITORS ──────────────────────────────────────────
-- Run this before creating new monitors to see what's already in place.

SHOW RESOURCE MONITORS;

-- Check which warehouses are assigned to which monitors:
SHOW WAREHOUSES;
-- Look at the RESOURCE_MONITOR column in the output.


-- ── STEP 2: CREATE A WAREHOUSE-LEVEL RESOURCE MONITOR ─────────────────────────
-- Replace ANALYTICS_WAREHOUSE with your actual warehouse name.
-- Replace 500 with your monthly credit budget for that warehouse.
--
-- Trigger pattern:
--   75%  → notify (early warning, no action)
--   100% → SUSPEND (wait for running queries to finish)
--   115% → SUSPEND_IMMEDIATE (kill all running queries)
--
-- The 115% overrun buffer prevents a tight quota from killing queries
-- mid-run when they started just before the 100% threshold was crossed.

CREATE OR REPLACE RESOURCE MONITOR analytics_wh_monitor
    WITH CREDIT_QUOTA = 500
    TRIGGERS
        ON  75 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND
        ON 115 PERCENT DO SUSPEND_IMMEDIATE;

-- Assign the monitor to the warehouse:
ALTER WAREHOUSE analytics_wh SET RESOURCE_MONITOR = analytics_wh_monitor;

-- Verify the assignment:
SHOW WAREHOUSES LIKE 'analytics_wh';


-- ── STEP 3: MULTI-WAREHOUSE MONITOR ──────────────────────────────────────────
-- A single resource monitor can cover multiple warehouses.
-- The quota is shared — if WH1 uses 400 credits and WH2 uses 200,
-- both are suspended when the shared quota of 500 is reached.
--
-- Use this pattern for teams that own a cluster of warehouses
-- and should share a combined budget.

CREATE OR REPLACE RESOURCE MONITOR dev_team_monitor
    WITH CREDIT_QUOTA = 200
    TRIGGERS
        ON  80 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE dev_wh_xs  SET RESOURCE_MONITOR = dev_team_monitor;
ALTER WAREHOUSE dev_wh_sm  SET RESOURCE_MONITOR = dev_team_monitor;
ALTER WAREHOUSE dev_wh_batch SET RESOURCE_MONITOR = dev_team_monitor;


-- ── STEP 4: ACCOUNT-LEVEL RESOURCE MONITOR ────────────────────────────────────
-- An account-level monitor fires on total warehouse credit consumption
-- across ALL warehouses in the account.
--
-- Important constraints:
--   - Only one account-level monitor is allowed per account.
--   - Does NOT override individual warehouse monitors (both can fire independently).
--   - Does NOT cover serverless, AI services, or any non-warehouse compute.

CREATE OR REPLACE RESOURCE MONITOR account_ceiling_monitor
    WITH CREDIT_QUOTA = 5000
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON  70 PERCENT DO NOTIFY
        ON  90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND
        ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER ACCOUNT SET RESOURCE_MONITOR = account_ceiling_monitor;

-- Note: SUSPEND at the account level suspends ALL warehouses in the account.
-- Use this only if you want a hard ceiling — the 90% NOTIFY gives early warning.


-- ── STEP 5: WEEKLY RESET MONITOR ─────────────────────────────────────────────
-- For development or burst workloads that should be capped weekly
-- rather than monthly.

CREATE OR REPLACE RESOURCE MONITOR etl_weekly_monitor
    WITH CREDIT_QUOTA = 150
    FREQUENCY = WEEKLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON  80 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE etl_wh SET RESOURCE_MONITOR = etl_weekly_monitor;


-- ── STEP 6: ADD NON-ADMIN USERS TO NOTIFICATIONS ─────────────────────────────
-- By default, notifications only go to account administrators.
-- To notify a warehouse owner who isn't an admin, add them with NOTIFY_USERS.
-- All listed users must have verified email addresses.
-- Note: NOTIFY_USERS cannot be set on account-level monitors.

ALTER RESOURCE MONITOR analytics_wh_monitor
    SET NOTIFY_USERS = (WH_OWNER_USER, COST_TRACKER_USER);


-- ── STEP 7: MODIFYING AN EXISTING MONITOR ────────────────────────────────────
-- !! CRITICAL GOTCHA !!
-- The TRIGGERS parameter in ALTER RESOURCE MONITOR is NOT additive.
-- If you specify TRIGGERS, it REPLACES all existing triggers.
-- You must include every trigger you want to keep.
--
-- This is wrong — it drops the 75% NOTIFY trigger:
--
--   ALTER RESOURCE MONITOR analytics_wh_monitor SET CREDIT_QUOTA = 750
--     TRIGGERS ON 100 PERCENT DO SUSPEND;   -- WRONG: lost the 75% notify
--
-- This is correct — re-specify all triggers when altering:

ALTER RESOURCE MONITOR analytics_wh_monitor
    SET CREDIT_QUOTA = 750
    TRIGGERS
        ON  75 PERCENT DO NOTIFY           -- keep this
        ON 100 PERCENT DO SUSPEND          -- keep this
        ON 115 PERCENT DO SUSPEND_IMMEDIATE; -- keep this


-- ── STEP 8: VERIFICATION QUERIES ─────────────────────────────────────────────

-- Show all resource monitors and their current state:
SHOW RESOURCE MONITORS;

-- Show warehouse assignments:
SELECT
    "name"              AS warehouse_name,
    "resource_monitor"  AS monitor_name
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
-- (Run after SHOW WAREHOUSES to get the resource_monitor column)
;

-- Alternatively, use SHOW WAREHOUSES to see assignments:
SHOW WAREHOUSES;


-- ── STEP 9: REMOVE OR RESET MONITORS ─────────────────────────────────────────

-- Remove the monitor from a specific warehouse:
ALTER WAREHOUSE analytics_wh UNSET RESOURCE_MONITOR;

-- Remove the account-level monitor:
ALTER ACCOUNT UNSET RESOURCE_MONITOR;

-- Drop a monitor (only after unassigning all warehouses):
DROP RESOURCE MONITOR IF EXISTS dev_team_monitor;

-- Resume a warehouse that was suspended by a resource monitor:
-- First, either increase the quota or unassign the monitor:
ALTER RESOURCE MONITOR dev_team_monitor SET CREDIT_QUOTA = 300;
-- Then the warehouse can be manually resumed or will auto-resume on next query.
ALTER WAREHOUSE dev_wh_xs RESUME;
