/*==============================================================================
TEARDOWN ALL - Snowflake Cortex Agents for Microsoft Teams & M365 Copilot
WARNING: This will DELETE all demo objects. Cannot be undone (except Time Travel).
INSTRUCTIONS: Open in Snowsight -> Click "Run All"
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- 1. REVOKE GRANTS
-- ============================================================================

REVOKE USAGE ON AGENT SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.JOKE_ASSISTANT FROM ROLE PUBLIC;
REVOKE USAGE ON FUNCTION SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.GENERATE_SAFE_JOKE(VARCHAR) FROM ROLE PUBLIC;
REVOKE USAGE ON WAREHOUSE SFE_TEAMS_AGENT_UNI_WH FROM ROLE PUBLIC;
REVOKE USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI FROM ROLE PUBLIC;

-- ============================================================================
-- 2. DROP AGENT
-- ============================================================================

DROP AGENT IF EXISTS SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.JOKE_ASSISTANT;

-- ============================================================================
-- 3. DROP FUNCTION
-- ============================================================================

DROP FUNCTION IF EXISTS SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.GENERATE_SAFE_JOKE(VARCHAR);

-- ============================================================================
-- 4. DROP SCHEMA (CASCADE removes any remaining objects)
-- ============================================================================

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI CASCADE;

-- ============================================================================
-- 5. DROP WAREHOUSE
-- ============================================================================

DROP WAREHOUSE IF EXISTS SFE_TEAMS_AGENT_UNI_WH;

-- ============================================================================
-- PROTECTED - NOT DROPPED:
-- SNOWFLAKE_EXAMPLE database (shared by all demos)
-- SFE_ENTRA_ID_CORTEX_AGENTS_INTEGRATION (reusable across demos)
-- ============================================================================

-- ============================================================================
-- MANUAL CLEANUP:
-- ============================================================================

/*
 * 1. UNINSTALL TEAMS APP:
 *    Teams -> Apps -> Snowflake Cortex Agents -> ... -> Uninstall
 *
 * 2. REVOKE ENTRA ID CONSENT (optional):
 *    Azure Portal -> Enterprise applications -> Snowflake Cortex Agents -> Delete
 *    (Removes both OAuth Resource and OAuth Client service principals)
 *
 * TIME TRAVEL RECOVERY:
 *    UNDROP SCHEMA SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI;
 */

SELECT 'Teardown complete' AS status;
