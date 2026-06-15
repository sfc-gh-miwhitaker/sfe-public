/******************************************************************************
 * Tool: Contact Form (Streamlit in Snowflake)
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
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SFE_CONTACT_FORM CASCADE;

-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================
SELECT
    '✅ TEARDOWN COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Contact Form (Streamlit)' AS tool,
    'Schema SFE_CONTACT_FORM and all objects removed' AS message;
