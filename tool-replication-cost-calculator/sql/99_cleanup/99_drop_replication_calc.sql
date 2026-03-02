/*****************************************************************************
 * CLEANUP SCRIPT: Replication Cost Calculator Demo
 *
 * Author: SE Community
 * Purpose: Removes all objects created by deploy_all.sql
 * Expires: 2026-04-10
 *
 * USAGE:
 * 1. Copy this entire script into Snowsight
 * 2. Click "Run All" to remove all demo objects
 * 3. Verify cleanup completed successfully
 *
 * SAFETY: Uses IF EXISTS - safe to run multiple times
 *
 * NOTE: Does NOT remove shared infrastructure:
 * - SFE_GIT_API_INTEGRATION (may be used by other demos)
 * - SNOWFLAKE_EXAMPLE database (contains other demos)
 * - SNOWFLAKE_EXAMPLE.GIT_REPOS schema (shared Git repos schema)
 *****************************************************************************/

-- ============================================================================
-- CONTEXT SETTING (MANDATORY)
-- ============================================================================
-- Cleanup script: Uses SYSADMIN for most drops, ACCOUNTADMIN for integrations.
-- No specific database/warehouse context needed (drops are fully qualified).
-- ============================================================================
USE ROLE SYSADMIN;

/*****************************************************************************
 * SECTION 1: Drop Application Objects
 *****************************************************************************/

-- Drop Streamlit app (created by deploy_all.sql)
DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.REPLICATION_CALC.REPLICATION_CALCULATOR;

/*****************************************************************************
 * SECTION 2: Drop Schema (CASCADE removes all tables, views, stages, procs)
 *****************************************************************************/

-- CASCADE will drop:
-- - PRICING_CURRENT table
-- - DB_METADATA view
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.REPLICATION_CALC CASCADE;

/*****************************************************************************
 * SECTION 3: Drop Warehouse
 *****************************************************************************/

DROP WAREHOUSE IF EXISTS SFE_REPLICATION_CALC_WH;

/*****************************************************************************
 * SECTION 4: Drop Git Repository Clone (ACCOUNTADMIN)
 * The clone is project-specific; the API integration is shared and preserved.
 *****************************************************************************/
USE ROLE ACCOUNTADMIN;

DROP GIT REPOSITORY IF EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.REPLICATE_THIS_REPO;

/*****************************************************************************
 * VERIFICATION: Show remaining objects
 *****************************************************************************/

-- Verify schema is gone
SHOW SCHEMAS LIKE 'REPLICATION_CALC' IN DATABASE SNOWFLAKE_EXAMPLE;

-- Verify warehouse is gone
SHOW WAREHOUSES LIKE 'SFE_REPLICATION_CALC_WH';

-- Final status
SELECT
    'Cleanup Complete' AS STATUS,
    'All demo objects have been removed' AS MESSAGE,
    'Shared infrastructure (SNOWFLAKE_EXAMPLE DB, SNOWFLAKE_EXAMPLE.GIT_REPOS schema, SFE_GIT_API_INTEGRATION) preserved' AS NOTE;
