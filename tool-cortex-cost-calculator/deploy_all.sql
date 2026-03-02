/*******************************************************************************
 * DEMO PROJECT: Cortex Cost Calculator - Git-Integrated Deployment
 *
 * AUTHOR: SE Community
 * CREATED: 2026-01-05
 * LAST UPDATED: 2026-03-02
 * EXPIRES: 2026-05-01 (SSOT - update ONLY this line when extending)
 *
 * NOT FOR PRODUCTION USE - REFERENCE IMPLEMENTATION ONLY
 *
 * DEPLOYMENT METHOD: Copy/Paste into Snowsight
 *   1. Copy this ENTIRE script
 *   2. Open Snowsight -> New Worksheet
 *   3. Paste the script
 *   4. Click "Run All"
 *   5. Wait ~2 minutes for complete deployment
 *
 * PURPOSE:
 *   Single-script deployment leveraging Snowflake native Git integration.
 *   Creates API Integration -> Git Repository -> Executes SQL from Git ->
 *   Deploys Streamlit from Git.
 *
 * OBJECTS CREATED:
 *
 *   Account-Level:
 *   - API Integration: SFE_GIT_API_INTEGRATION
 *
 *   Database-Level (SNOWFLAKE_EXAMPLE):
 *   - Database: SNOWFLAKE_EXAMPLE
 *   - Schema: GIT_REPOS (shared infrastructure)
 *   - Schema: CORTEX_USAGE
 *   - Git Repository: SFE_CORTEX_TRAIL_REPO
 *   - 22 views (monitoring + attribution + forecast)
 *   - 1 snapshot table (CORTEX_USAGE_SNAPSHOTS)
 *   - 1 serverless task (TASK_DAILY_CORTEX_SNAPSHOT)
 *   - 1 Streamlit app (CORTEX_COST_CALCULATOR)
 *
 * GITHUB REPOSITORY:
 *   https://github.com/sfc-gh-miwhitaker/sfe-public
 *
 * PREREQUISITES:
 *   - ACCOUNTADMIN role OR role with:
 *     * CREATE DATABASE, CREATE WAREHOUSE (if no active warehouse)
 *     * CREATE API INTEGRATION
 *     * CREATE GIT REPOSITORY
 *     * IMPORTED PRIVILEGES on SNOWFLAKE database
 *   - Warehouse auto-created if none active (SFE_DEMO_DEPLOY_WH)
 *
 * DEPLOYMENT TIME: ~2 minutes
 *
 * CLEANUP:
 *   Run sql/99_cleanup/cleanup_all.sql for complete removal
 *
 * VERSION: 3.3 (REST API tracking, Feb 2026 pricing, input/output token breakdown)
 * LAST UPDATED: 2026-02-18
 ******************************************************************************/

-- ===========================================================================
-- WAREHOUSE CHECK (MANDATORY - Must run FIRST)
-- ===========================================================================
-- All subsequent operations require an active warehouse for compute.
-- This block ensures a warehouse is available before proceeding.

SET demo_expiration_date = '2026-05-01';  -- SSOT: mirrors line 7

-- Capture current warehouse (may be NULL if user has no default)
SET _current_wh = (SELECT CURRENT_WAREHOUSE());

-- If no warehouse, create a temporary one for deployment
EXECUTE IMMEDIATE $$
BEGIN
    IF (CURRENT_WAREHOUSE() IS NULL) THEN
        CREATE WAREHOUSE IF NOT EXISTS SFE_DEMO_DEPLOY_WH
            WAREHOUSE_SIZE = 'XSMALL'
            AUTO_SUSPEND = 60
            AUTO_RESUME = TRUE
            INITIALLY_SUSPENDED = FALSE
            COMMENT = 'Temporary warehouse for demo deployment - safe to drop after deployment';
        USE WAREHOUSE SFE_DEMO_DEPLOY_WH;
    END IF;
END;
$$;

-- ===========================================================================
-- EXPIRATION CHECK (Informational — warns but does not block deployment)
-- ===========================================================================
-- SINGLE SOURCE OF TRUTH: Update ONLY the date on line 6 of this file header.
-- All object COMMENTs below reference this date dynamically where possible.
-- If expired, fork the repository and refresh the dates and syntax.

SELECT
    $demo_expiration_date::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), $demo_expiration_date::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), $demo_expiration_date::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), $demo_expiration_date::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), $demo_expiration_date::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), $demo_expiration_date::DATE) || ' days remaining'
    END AS demo_status;

-- This demo uses Snowflake features current as of February 2026.
-- To use after expiration:
--   1. Fork: https://github.com/sfc-gh-miwhitaker/sfe-public
--   2. Update expiration_date in this file
--   3. Review/update for latest Snowflake syntax and features

-- ===========================================================================
-- STEP 1: CREATE API INTEGRATION (Account-level object for GitHub access)
-- ===========================================================================
-- Requires ACCOUNTADMIN or CREATE API INTEGRATION privilege
-- Creates: SFE_GIT_API_INTEGRATION (shared across sfe-public projects)

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
    ENABLED = TRUE
    COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

-- ===========================================================================
-- STEP 2: CREATE DATABASE & SCHEMAS
-- ===========================================================================
-- Creates: SNOWFLAKE_EXAMPLE database (demo container)
-- Creates: GIT_REPOS schema (shared infrastructure)
-- Creates: CORTEX_USAGE schema (will be created by monitoring script)

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION | See deploy_all.sql for expiration';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
    COMMENT = 'DEMO: Shared schema for Git repository stages across demo projects | See deploy_all.sql for expiration';

-- Set context for Git repository creation
USE SCHEMA SNOWFLAKE_EXAMPLE.GIT_REPOS;

-- ===========================================================================
-- STEP 3: CREATE GIT REPOSITORY
-- ===========================================================================
-- Creates: SFE_CORTEX_TRAIL_REPO in GIT_REPOS schema
-- Connects to: https://github.com/sfc-gh-miwhitaker/sfe-public

CREATE OR REPLACE GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CORTEX_TRAIL_REPO
    API_INTEGRATION = SFE_GIT_API_INTEGRATION
    ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
    COMMENT = 'DEMO: cortex-trail - Cortex Cost Calculator toolkit repository | See deploy_all.sql for expiration';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CORTEX_TRAIL_REPO FETCH;

-- ===========================================================================
-- STEP 4: EXECUTE MONITORING DEPLOYMENT FROM GIT
-- ===========================================================================
-- Executes: sql/01_deployment/deploy_cortex_monitoring.sql from Git
-- Creates: CORTEX_USAGE schema, 22 views, 1 table, 1 task (forecast model optional)
-- Pattern: EXECUTE IMMEDIATE FROM Git stage (Snowflake native)

EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CORTEX_TRAIL_REPO/branches/main/tool-cortex-cost-calculator/sql/01_deployment/deploy_cortex_monitoring.sql;

-- ===========================================================================
-- STEP 5: DEPLOY STREAMLIT APP FROM GIT
-- ===========================================================================
-- Creates: CORTEX_COST_CALCULATOR Streamlit app
-- Location: SNOWFLAKE_EXAMPLE.CORTEX_USAGE
-- Source: Git repository (copied at deploy time; update with ALTER STREAMLIT ... PULL after a FETCH)
-- Note: Uses COMPUTE_WH as default. Change to your warehouse if different.

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- Capture current warehouse for Streamlit deployment
SET streamlit_warehouse = (SELECT CURRENT_WAREHOUSE());

CREATE OR REPLACE STREAMLIT SNOWFLAKE_EXAMPLE.CORTEX_USAGE.CORTEX_COST_CALCULATOR
    FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CORTEX_TRAIL_REPO/branches/main/tool-cortex-cost-calculator/streamlit/cortex_cost_calculator/
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = $streamlit_warehouse
    TITLE = 'Cortex Cost Calculator'
    COMMENT = 'DEMO: cortex-trail - Interactive cost analysis and forecasting for Cortex services | See deploy_all.sql for expiration';

-- Ensure the app has a live version (avoids requiring an owner to open the app once in Snowsight)
ALTER STREAMLIT SNOWFLAKE_EXAMPLE.CORTEX_USAGE.CORTEX_COST_CALCULATOR ADD LIVE VERSION FROM LAST;

-- ===========================================================================
-- DEPLOYMENT COMPLETE
-- ===========================================================================
-- Objects Created:
--
-- Account-Level:
--   - API Integration: SFE_GIT_API_INTEGRATION
--   - Warehouse: SFE_DEMO_DEPLOY_WH (only if no warehouse was active)
--
-- Database-Level (SNOWFLAKE_EXAMPLE):
--   - Database: SNOWFLAKE_EXAMPLE
--   - Schema: GIT_REPOS (shared infrastructure)
--   - Schema: CORTEX_USAGE
--   - Git Repository: SFE_CORTEX_TRAIL_REPO
--   - Views: 22 views (monitoring + attribution + forecast)
--   - Table: CORTEX_USAGE_SNAPSHOTS
--   - Task: TASK_DAILY_CORTEX_SNAPSHOT (serverless)
--   - Streamlit App: CORTEX_COST_CALCULATOR
--
-- Next Steps:
--   1. Access app: Snowsight -> Projects -> Streamlit -> CORTEX_COST_CALCULATOR
--   2. Query views: SELECT usage_date, service_type, daily_unique_users, total_operations, total_credits FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY ORDER BY usage_date DESC LIMIT 10
--   3. Monitor task: Task runs daily at 3:00 AM Pacific
--
-- Cleanup:
--   Run sql/99_cleanup/cleanup_all.sql to remove all objects
--   If SFE_DEMO_DEPLOY_WH was created: DROP WAREHOUSE IF EXISTS SFE_DEMO_DEPLOY_WH;
--
-- Total deployment time: ~2 minutes

-- ===========================================================================
-- VALIDATION - Verify Deployment Success
-- ===========================================================================

-- Check 1: Git repository accessible and contains SQL files
LIST @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CORTEX_TRAIL_REPO/branches/main/tool-cortex-cost-calculator/sql/ PATTERN='.*\.sql';

-- Check 2: Views created (should be 21)
SELECT
    CASE
        WHEN COUNT(*) = 22 THEN 'SUCCESS: All 22 views created'
        ELSE 'WARNING: Expected 22 views, found ' || COUNT(*) || ' views'
    END AS validation_status
FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'CORTEX_USAGE'
    AND TABLE_CATALOG = 'SNOWFLAKE_EXAMPLE';

-- Check 3: Snapshot table exists
SELECT
    CASE
        WHEN COUNT(*) = 1 THEN 'SUCCESS: Snapshot table created'
        ELSE 'WARNING: Snapshot table not found'
    END AS validation_status
FROM SNOWFLAKE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CORTEX_USAGE'
    AND TABLE_CATALOG = 'SNOWFLAKE_EXAMPLE'
    AND TABLE_NAME = 'CORTEX_USAGE_SNAPSHOTS';

-- Check 4: Serverless task created and running
SHOW TASKS LIKE 'TASK_DAILY_CORTEX_SNAPSHOT' IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- Check 5: Streamlit app accessible
SHOW STREAMLITS LIKE 'CORTEX_COST_CALCULATOR' IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- Check 6: Test data access (empty result is normal if no Cortex usage yet)
SELECT
    COUNT(*) AS row_count,
    CASE
        WHEN COUNT(*) > 0 THEN 'Data available - views are working'
        ELSE 'No data yet (normal if account has no Cortex usage)'
    END AS data_status
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY;

-- ===========================================================================
-- TROUBLESHOOTING GUIDE
-- ===========================================================================

-- Common Issues and Solutions:
--
-- 1. "API integration not found"
--    -> Requires ACCOUNTADMIN or CREATE API INTEGRATION privilege
--    -> Switch role: USE ROLE ACCOUNTADMIN;
--
-- 2. "Git repository fetch failed"
--    -> Verify repo is public: https://github.com/sfc-gh-miwhitaker/sfe-public
--    -> Check network connectivity to GitHub
--
-- 3. "EXECUTE IMMEDIATE FROM failed"
--    -> Verify warehouse is running
--    -> Verify Git fetch completed successfully
--    -> Check file exists: LIST @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CORTEX_TRAIL_REPO/branches/main/tool-cortex-cost-calculator/sql/01_deployment/;
--
-- 4. "Streamlit app creation failed"
--    -> Verify streamlit_app.py exists in Git repo
--    -> Check path: LIST @...SFE_CORTEX_TRAIL_REPO/branches/main/tool-cortex-cost-calculator/streamlit/cortex_cost_calculator/;
--
-- 5. "Views return no data"
--    -> Normal if account has no Cortex usage yet
--    -> Views will populate after using Cortex services
--    -> Check permissions: GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;
--
-- Detailed docs: See docs/03-TROUBLESHOOTING.md in GitHub repository
