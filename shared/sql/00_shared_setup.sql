/******************************************************************************
 * Snowflake Tools Collection
 * File: shared/sql/00_shared_setup.sql
 * Author: SE Community
 *
 * Purpose: Creates shared infrastructure used by all tools in this collection
 *
 * Run This First: Before deploying any tool, run this script once to create
 * the shared database, warehouse, Git integration, and Git-repos schema.
 *
 * How to Use:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 *
 * What This Creates:
 *   - Database: SNOWFLAKE_EXAMPLE (shared across all tools)
 *   - Schema: SNOWFLAKE_EXAMPLE.GIT_REPOS (Git repository stages)
 *   - Warehouse: SFE_TOOLS_WH (shared compute, X-SMALL)
 *   - API Integration: SFE_GIT_API_INTEGRATION (GitHub access for sfe-public)
 *
 * Safe to Re-Run: Uses IF NOT EXISTS, won't overwrite existing objects
 ******************************************************************************/

-- ============================================================================
-- ACCOUNT-LEVEL OBJECTS (ACCOUNTADMIN required)
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;  -- Bootstrap with existing warehouse

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
    ENABLED = TRUE
    COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

-- ============================================================================
-- DATABASE-LEVEL OBJECTS (SYSADMIN)
-- ============================================================================
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE demonstration projects and tools | Author: SE Community';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
    COMMENT = 'Shared schema for Git repository stages across demo projects | Author: SE Community';

-- ============================================================================
-- CREATE SHARED WAREHOUSE
-- ============================================================================
CREATE WAREHOUSE IF NOT EXISTS SFE_TOOLS_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Shared warehouse for Snowflake Tools Collection | Author: SE Community';

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
SELECT
    '✅ SHARED SETUP COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'SNOWFLAKE_EXAMPLE database ready' AS database_status,
    'SNOWFLAKE_EXAMPLE.GIT_REPOS schema ready' AS git_repos_status,
    'SFE_TOOLS_WH warehouse ready' AS warehouse_status,
    'SFE_GIT_API_INTEGRATION ready' AS git_integration_status,
    'You can now deploy individual tools' AS next_step;

-- =============================================================================
-- VERIFICATION QUERIES (Run individually if needed)
-- =============================================================================

/*
 * -- Verify database exists
 * SHOW DATABASES LIKE 'SNOWFLAKE_EXAMPLE';
 *
 * -- Verify warehouse exists
 * SHOW WAREHOUSES LIKE 'SFE_TOOLS_WH';
 *
 * -- List all tool schemas
 * SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;
 */
