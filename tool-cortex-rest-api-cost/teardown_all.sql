/******************************************************************************
 * Tool: Cortex REST API Cost
 * File: teardown_all.sql
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

-- ============================================================================
-- DROP STREAMLIT AND NOTEBOOK
-- ============================================================================
DROP NOTEBOOK IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_REST_API_COST.CORTEX_REST_API_COST_NOTEBOOK;
DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_REST_API_COST.CORTEX_REST_API_COST_APP;

-- ============================================================================
-- DROP SCHEMA (CASCADE removes all tables, views)
-- ============================================================================
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_REST_API_COST CASCADE;

-- ============================================================================
-- DROP WAREHOUSE
-- ============================================================================
DROP WAREHOUSE IF EXISTS SFE_CORTEX_REST_API_COST_WH;

-- ============================================================================
-- PROTECTED - NEVER DROP:
-- SNOWFLAKE_EXAMPLE database
-- SNOWFLAKE_EXAMPLE.GIT_REPOS schema
-- SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS schema (shared)
-- SFE_GIT_API_INTEGRATION
-- ============================================================================

-- ============================================================================
-- TEARDOWN COMPLETE
-- ============================================================================
SELECT
    'TEARDOWN COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Cortex REST API Cost' AS tool,
    'Schema CORTEX_REST_API_COST, warehouse, Streamlit app, and notebook removed' AS message;
