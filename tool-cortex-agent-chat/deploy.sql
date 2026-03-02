/******************************************************************************
 * Tool: Cortex Agent Chat (React UI)
 * File: deploy.sql
 * Author: SE Community
 * Created: 2025-12-15
 * Expires: 2026-01-14 (30 days from creation)
 *
 * Purpose: Creates a sample Cortex Agent and supporting infrastructure for
 *          the React chat application to consume via REST API with key-pair JWT auth.
 *
 * Prerequisites:
 *   1. Run shared/sql/00_shared_setup.sql first (creates database and warehouse)
 *   2. ACCOUNTADMIN role access (required to grant CORTEX_AGENT_USER role)
 *   3. Cortex Agents feature available in your Snowflake region
 *   4. RSA key-pair generated (run tools/01_setup.sh or see README for manual steps)
 *
 * How to Deploy (Automated - Recommended):
 *   1. Run: ./tools/01_setup.sh (generates keys, .env.local, and deploy_with_key.sql)
 *   2. Edit .env.local to update your Snowflake account name
 *   3. Copy deploy_with_key.sql into Snowsight → Run All
 *   4. Run: npm install && npm start
 *
 * How to Deploy (Manual):
 *   1. Copy this ENTIRE script into Snowsight → Run All
 *   2. Generate RSA key-pair and assign public key (see instructions below)
 *   3. Configure .env.local with your credentials and private key
 *   4. Run: npm install && npm start
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (MANDATORY)
-- ============================================================================
EXECUTE IMMEDIATE
$$
DECLARE
    v_expiration_date DATE := '2026-01-14';
    demo_expired EXCEPTION (-20001, 'TOOL EXPIRED: This tool expired on 2026-01-14. Please check for an updated version.');
BEGIN
    IF (CURRENT_DATE() > v_expiration_date) THEN
        RAISE demo_expired;
    END IF;
    RETURN 'Expiration check passed. Tool valid until ' || v_expiration_date::STRING;
END;
$$;

-- ============================================================================
-- CONTEXT SETTING (MANDATORY)
-- ============================================================================
USE ROLE ACCOUNTADMIN;  -- Required for granting CORTEX_AGENT_USER role
USE DATABASE SNOWFLAKE_EXAMPLE;
USE WAREHOUSE SFE_TOOLS_WH;

-- ============================================================================
-- GRANT CORTEX AGENTS ACCESS (REQUIRED PREREQUISITE)
-- ============================================================================
-- CRITICAL: Cortex Agents requires the CORTEX_AGENT_USER database role
-- Without this role, CREATE CORTEX AGENT syntax will fail with:
-- "syntax error line 1 at position 25 unexpected 'AGENT'"
--
-- This grants the CORTEX_AGENT_USER role to SYSADMIN so all SYSADMIN
-- users can create and use Cortex Agents.
--
-- Note: CORTEX_AGENT_USER provides access to Cortex Agents only
--       CORTEX_USER provides access to all Cortex AI features
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE SYSADMIN;

-- Switch back to SYSADMIN for object creation
USE ROLE SYSADMIN;

-- ============================================================================
-- CREATE TOOL SCHEMA
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS SFE_CORTEX_AGENT_CHAT
    COMMENT = 'TOOL: Cortex Agent Chat - React UI for Cortex Agent interaction | Author: SE Community | Expires: 2026-01-14';

USE SCHEMA SFE_CORTEX_AGENT_CHAT;

-- ============================================================================
-- CREATE SAMPLE CORTEX AGENT
-- ============================================================================
CREATE OR REPLACE AGENT SFE_REACT_DEMO_AGENT
    COMMENT = 'TOOL: React Demo Agent - Cortex Agent for React chat interface | Author: SE Community | Expires: 2026-01-14'
    PROFILE = '{"display_name": "SFE React Demo Agent", "avatar": "snowflake-logo.png", "color": "#29B5E8"}'
    FROM SPECIFICATION
    $$
    models:
      orchestration: auto

    instructions:
      system: "You are the SFE React Demo Agent, helping users understand Snowflake capabilities through this React chat interface. You specialize in explaining Snowflake features, data warehousing concepts, SQL optimization, and Cortex AI capabilities. Provide concise, accurate responses with clear examples. If uncertain, acknowledge it clearly. This chat interface demonstrates REST API integration with Cortex Agents using key-pair JWT authentication from a React.js application."
      response: "Keep responses concise and well-structured. Use bullet points for lists and code blocks for SQL examples."
      sample_questions:
        - question: "How does this chat interface work?"
          answer: "This React application connects to me via Snowflake's REST API using secure key-pair JWT authentication. When you send a message, it's transmitted to Snowflake where I process it using Claude AI and stream the response back in real-time."
        - question: "What is Snowflake Cortex?"
          answer: "Snowflake Cortex is an AI platform built into Snowflake that includes: LLM functions (COMPLETE, CHAT), AI agents like me, semantic search, and ML capabilities - all running natively in your data warehouse without moving data."
        - question: "How do I optimize SQL queries?"
          answer: "Key optimization techniques: 1) Add filters in WHERE clauses (push down predicates), 2) Avoid SELECT * (project only needed columns), 3) Use clustering keys for large tables, 4) Leverage materialized views for repeated aggregations, 5) Use QUALIFY for window function filtering."
        - question: "What are key-pair JWTs?"
          answer: "Key-pair JWT authentication uses asymmetric cryptography: you generate an RSA key-pair (private + public), assign the public key to your Snowflake user, and your application signs JWT tokens with the private key. This is more secure than passwords and doesn't require token refresh management."
    $$;

-- ============================================================================
-- GRANT USAGE TO CURRENT ROLE
-- ============================================================================
-- This allows the current user/role to interact with the agent
GRANT USAGE ON AGENT SFE_REACT_DEMO_AGENT TO ROLE SYSADMIN;

-- ============================================================================
-- INSTRUCTIONS FOR KEY-PAIR AUTHENTICATION SETUP
-- ============================================================================
-- To use this agent with the React app, you need to set up key-pair authentication
--
-- Step 1: Generate RSA Key-Pair (on your local machine)
--
-- # Generate private key (2048-bit RSA)
-- openssl genrsa -out rsa_key.pem 2048
--
-- # Extract public key from private key
-- openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub
--
-- Step 2: Get Public Key Content (without BEGIN/END lines)
--
-- # View public key content
-- cat rsa_key.pub | grep -v "BEGIN PUBLIC KEY" | grep -v "END PUBLIC KEY" | tr -d '\n'
--
-- # This gives you a long string like: MIIBIjANBgkqhki...
--
-- Step 3: Assign Public Key to Your Snowflake User
--
-- Replace <your_username> with your actual Snowflake username
-- Replace <public_key_content> with the string from Step 2
--
-- USE ROLE ACCOUNTADMIN;  -- Required for ALTER USER
-- ALTER USER <your_username> SET RSA_PUBLIC_KEY='<public_key_content>';
--
-- Example:
-- ALTER USER DEMO_USER SET RSA_PUBLIC_KEY='MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...';
--
-- Step 4: Verify Public Key Assignment
--
-- DESC USER <your_username>;
-- -- Look for RSA_PUBLIC_KEY_FP property (fingerprint should be set)
--
-- SECURITY NOTES:
-- - Keep rsa_key.pem (private key) secure - never commit to version control
-- - Public key is safe to assign to your Snowflake user
-- - Private key stays on your machine - never sent over network
-- - JWT tokens are generated client-side and expire after 1 hour
-- - No network policy required for key-pair authentication

-- ============================================================================
-- VERIFY AGENT CREATION
-- ============================================================================
-- List all agents in the schema
SHOW AGENTS IN SCHEMA SFE_CORTEX_AGENT_CHAT;

-- Describe the specific agent (shows full configuration)
DESC AGENT SFE_REACT_DEMO_AGENT;

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    '✅ DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Cortex Agent Chat (React UI)' AS tool,
    'SFE_REACT_DEMO_AGENT' AS agent_name,
    '2026-01-14' AS expires,
    'If using automated setup (tools/01_setup.sh):' AS next_steps_automated,
    '  1. Edit .env.local (update SNOWFLAKE_ACCOUNT)' AS auto_step_1,
    '  2. Run: npm install && npm start' AS auto_step_2,
    '  3. Open: http://localhost:3001' AS auto_step_3,
    'If using manual setup:' AS next_steps_manual,
    '  1. Generate RSA key-pair and assign public key' AS manual_step_1,
    '  2. Configure .env.local with credentials' AS manual_step_2,
    '  3. Run: npm install && npm start' AS manual_step_3;
