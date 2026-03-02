/******************************************************************************
 * Tool: Cortex Agent Chat (React UI)
 * File: teardown.sql
 * Author: SE Community
 *
 * Purpose: Removes all Snowflake objects created by this tool
 *
 * What This Removes:
 *   - Schema SFE_CORTEX_AGENT_CHAT (and all contained objects)
 *   - Cortex Agent SFE_REACT_DEMO_AGENT
 *
 * What This Does NOT Remove:
 *   - Shared infrastructure (SNOWFLAKE_EXAMPLE database, SFE_TOOLS_WH warehouse)
 *   - Your RSA public key assignment (can be removed manually if desired)
 *   - Local React app files (remove manually: rm -rf node_modules)
 *   - Local private key file (delete manually: rm rsa_key.pem)
 *
 * How to Use:
 *   1. Stop the React development server (Ctrl+C)
 *   2. Copy this ENTIRE script into Snowsight
 *   3. Click "Run All"
 *   4. Optionally revoke your PAT (see instructions below)
 ******************************************************************************/

-- ============================================================================
-- CONTEXT SETTING (MANDATORY)
-- ============================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE SFE_TOOLS_WH;

-- ============================================================================
-- DROP TOOL SCHEMA (CASCADE removes all contained objects)
-- ============================================================================
-- This removes:
-- - SFE_REACT_DEMO_AGENT (Cortex Agent)
-- - Any other objects in the schema

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT CASCADE;

-- ============================================================================
-- PUBLIC KEY CLEANUP (OPTIONAL - MANUAL)
-- ============================================================================
-- Public key assignment can be removed if no longer needed
--
-- To remove your public key:
--
-- 1. Check current key assignment:
--    DESC USER <your_username>;
--
-- 2. Unset the public key:
--    ALTER USER <your_username> UNSET RSA_PUBLIC_KEY;
--
-- 3. Verify removal:
--    DESC USER <your_username>;
--    -- RSA_PUBLIC_KEY_FP should now be null
--
-- Or via Snowsight:
--    Admin > Users & Roles > [Your User] > RSA Public Keys > Remove

-- ============================================================================
-- LOCAL CLEANUP INSTRUCTIONS
-- ============================================================================
-- Remove local React application files:
--
-- cd tools/cortex-agent-chat
-- rm -rf node_modules  # Remove dependencies
-- rm -rf build         # Remove production build
-- rm .env.local        # Remove local configuration (contains private key)
-- rm rsa_key.pem       # Remove private key file
-- rm rsa_key.pub       # Remove public key file
--
-- Or remove entire tool directory:
-- cd ..
-- rm -rf cortex-agent-chat

-- ============================================================================
-- TEARDOWN COMPLETE
-- ============================================================================
SELECT
    '✅ TEARDOWN COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Cortex Agent Chat (React UI)' AS tool,
    'Schema and agent removed' AS snowflake_cleanup,
    'Unset public key if desired (see instructions above)' AS manual_step_1,
    'Remove local files: node_modules, .env.local, rsa_key.pem' AS manual_step_2;
