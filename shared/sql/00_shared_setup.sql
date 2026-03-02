/******************************************************************************
 * Snowflake Tools Collection
 * File: shared/sql/00_shared_setup.sql
 * Author: SE Community
 *
 * Purpose: Creates shared infrastructure used by all tools in this collection
 *
 * Run This First: Before deploying any tool, run this script once to create
 * the shared database and warehouse.
 *
 * How to Use:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 *
 * What This Creates:
 *   - Database: SNOWFLAKE_EXAMPLE (shared across all tools)
 *   - Warehouse: SFE_TOOLS_WH (shared compute, X-SMALL)
 *
 * Safe to Re-Run: Uses IF NOT EXISTS, won't overwrite existing objects
 ******************************************************************************/

-- ============================================================================
-- CONTEXT SETTING (MANDATORY)
-- ============================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;  -- Bootstrap with existing warehouse

-- ============================================================================
-- CREATE SHARED DATABASE
-- ============================================================================
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE demonstration projects and tools | Author: SE Community';

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
    'SFE_TOOLS_WH warehouse ready' AS warehouse_status,
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
