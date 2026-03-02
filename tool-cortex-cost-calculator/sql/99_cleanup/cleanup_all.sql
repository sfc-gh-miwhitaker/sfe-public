/*******************************************************************************
 * DEMO PROJECT: Cortex Cost Calculator - Complete Cleanup
 *
 * AUTHOR: SE Community
 * CREATED: 2026-01-05
 * See deploy_all.sql for expiration (30 days)
 *
 * PURPOSE:
 *   Remove ALL objects created by deploy_all.sql
 *
 * WHAT GETS REMOVED:
 *   - Streamlit app: CORTEX_COST_CALCULATOR
 *   - Git repository: SFE_CORTEX_TRAIL_REPO
 *   - API integration: SFE_CORTEX_TRAIL_GIT_API
 *   - Schema: CORTEX_USAGE (all views, tables, tasks)
 *
 * WHAT STAYS (Protected shared infrastructure):
 *   - SNOWFLAKE_EXAMPLE database (may be used by other demos)
 *   - SNOWFLAKE_EXAMPLE.GIT_REPOS schema (shared across demos)
 *   - Source data in ACCOUNT_USAGE
 *
 * DEPLOYMENT METHOD: Copy/Paste into Snowsight
 *   1. Copy this ENTIRE script
 *   2. Open Snowsight -> New Worksheet
 *   3. Paste the script
 *   4. Click "Run All"
 *   5. Wait ~30 seconds for cleanup
 *
 * ERROR HANDLING:
 *   - All DROP commands use IF EXISTS (safe to run multiple times)
 *   - Validation queries at end verify cleanup success
 *
 * TIME: < 1 minute
 *
 * VERSION: 3.3 (Standards-compliant: SFE_ prefixes, ASCII-only)
 * LAST UPDATED: 2026-02-18
 ******************************************************************************/

-- ===========================================================================
-- STEP 1: SUSPEND AND DROP TASKS (must be done before schema drop)
-- ===========================================================================
-- Tasks must be suspended before they can be dropped
-- This prevents "task is running" errors

ALTER TASK IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_USAGE.TASK_DAILY_CORTEX_SNAPSHOT SUSPEND;

-- ===========================================================================
-- STEP 2: DROP STREAMLIT APP
-- ===========================================================================
-- Must be dropped before schema since it references schema objects

DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_USAGE.CORTEX_COST_CALCULATOR;

-- ===========================================================================
-- STEP 3: DROP MONITORING SCHEMA (with all objects)
-- ===========================================================================
-- CASCADE automatically drops all objects in the schema:
--   - 22 views (monitoring + attribution + forecast outputs)
--   - 1 table (CORTEX_USAGE_SNAPSHOTS)
--   - 1 task (TASK_DAILY_CORTEX_SNAPSHOT)

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_USAGE CASCADE;

-- ===========================================================================
-- STEP 4: DROP GIT REPOSITORY
-- ===========================================================================

DROP GIT REPOSITORY IF EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CORTEX_TRAIL_REPO;

-- ===========================================================================
-- STEP 5: DROP API INTEGRATION
-- ===========================================================================
-- Requires ACCOUNTADMIN or role with CREATE INTEGRATION privilege

DROP API INTEGRATION IF EXISTS SFE_CORTEX_TRAIL_GIT_API;

-- ===========================================================================
-- CLEANUP COMPLETE
-- ===========================================================================
-- Removed Objects:
--   - Task: TASK_DAILY_CORTEX_SNAPSHOT (suspended & dropped via CASCADE)
--   - Streamlit App: CORTEX_COST_CALCULATOR
--   - Schema: CORTEX_USAGE (22 views + table + task)
--   - Git Repository: SFE_CORTEX_TRAIL_REPO
--   - API Integration: SFE_CORTEX_TRAIL_GIT_API
--
-- Protected (Not Removed):
--   - Database: SNOWFLAKE_EXAMPLE (may contain other demos)
--   - Schema: SNOWFLAKE_EXAMPLE.GIT_REPOS (shared infrastructure)
--   - Source data: SNOWFLAKE.ACCOUNT_USAGE (unaffected)
--
-- Total cleanup time: < 1 minute

-- ===========================================================================
-- VERIFICATION - Confirm Cleanup Success
-- ===========================================================================
-- Run these queries to verify all objects were removed
-- All queries should return 0 rows or show "does not exist"

-- Check 1: API Integration should NOT exist
SHOW API INTEGRATIONS LIKE 'SFE_CORTEX_TRAIL_GIT_API';

-- Check 2: Schema should NOT exist
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'SUCCESS: CORTEX_USAGE schema removed'
        ELSE 'WARNING: CORTEX_USAGE schema still exists'
    END AS verification_status
FROM SNOWFLAKE.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME = 'CORTEX_USAGE'
    AND CATALOG_NAME = 'SNOWFLAKE_EXAMPLE';

-- Check 3: Git Repository should NOT exist
SHOW GIT REPOSITORIES LIKE 'SFE_CORTEX_TRAIL_REPO' IN ACCOUNT;

-- ===========================================================================
-- TROUBLESHOOTING GUIDE
-- ===========================================================================
--
-- If cleanup failed with permission errors:
--
-- 1. API Integration errors:
--    -> Switch to ACCOUNTADMIN role
--    -> USE ROLE ACCOUNTADMIN;
--    -> Re-run this cleanup script
--
-- 2. Schema/Object errors:
--    -> Verify you have OWNERSHIP on CORTEX_USAGE schema
--    -> Or use ACCOUNTADMIN role
--
-- 3. Git Repository errors:
--    -> Verify you have OWNERSHIP on GIT_REPOS schema or ACCOUNTADMIN
--
-- 4. Partial cleanup (some objects remain):
--    -> Safe to re-run this script multiple times
--    -> Use SHOW commands above to identify remaining objects
--
-- For complete manual cleanup (removes ALL demos):
--    DROP DATABASE SNOWFLAKE_EXAMPLE CASCADE;
--    DROP API INTEGRATION SFE_CORTEX_TRAIL_GIT_API;
