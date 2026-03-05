/******************************************************************************
 * Tool: DR Cost Agent (Snowflake Intelligence)
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

-- ============================================================================
-- DROP AGENT
-- ============================================================================
DROP AGENT IF EXISTS SNOWFLAKE_EXAMPLE.DR_COST_AGENT.DR_COST_AGENT;

-- ============================================================================
-- DROP SEMANTIC VIEW
-- ============================================================================
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST;

-- ============================================================================
-- DROP SCHEMA (CASCADE removes all tables, views, procedures)
-- ============================================================================
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.DR_COST_AGENT CASCADE;

-- ============================================================================
-- PROTECTED - NEVER DROP:
-- SNOWFLAKE_EXAMPLE database
-- SNOWFLAKE_EXAMPLE.GIT_REPOS schema
-- SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS schema (shared)
-- SFE_GIT_API_INTEGRATION
-- SFE_TOOLS_WH (shared)
-- ============================================================================

-- ============================================================================
-- TEARDOWN COMPLETE
-- ============================================================================
SELECT
    'TEARDOWN COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'DR Cost Agent' AS tool,
    'Schema DR_COST_AGENT, agent, and semantic view removed' AS message;
