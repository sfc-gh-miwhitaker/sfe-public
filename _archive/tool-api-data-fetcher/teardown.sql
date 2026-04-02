/******************************************************************************
 * Tool: API Data Fetcher
 * File: teardown.sql
 * Author: SE Community
 *
 * Purpose: Removes all objects created by this tool
 *
 * How to Use:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 ******************************************************************************/

-- ============================================================================
-- CONTEXT SETTING (MANDATORY)
-- ============================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE SFE_TOOLS_WH;

-- ============================================================================
-- DROP TOOL SCHEMA (CASCADE removes all contained objects)
-- ============================================================================
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SFE_API_FETCHER CASCADE;

-- ============================================================================
-- DROP EXTERNAL ACCESS INTEGRATION
-- ============================================================================
DROP INTEGRATION IF EXISTS SFE_API_ACCESS;

-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================
SELECT
    '✅ TEARDOWN COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'API Data Fetcher' AS tool,
    'Schema SFE_API_FETCHER and integration removed' AS message;
