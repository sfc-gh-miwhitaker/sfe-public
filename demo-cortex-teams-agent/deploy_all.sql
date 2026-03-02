/*==============================================================================
DEPLOY ALL - Snowflake Cortex Agents for Microsoft Teams & M365 Copilot
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-01
INSTRUCTIONS: Open in Snowsight -> Click "Run All"
==============================================================================*/

/*******************************************************************************
 * DEMO METADATA (Machine-readable - Do not modify format)
 * PROJECT_NAME: teams-agent-uni
 * AUTHOR: SE Community
 * CREATED: 2026-03-02
 * EXPIRES: 2026-04-01
 * GITHUB_REPO: sfe-public
 * PURPOSE: Snowflake Cortex Agents for Microsoft Teams & M365 Copilot demo
 *
 * PREREQUISITES:
 * - ACCOUNTADMIN role access
 * - Cortex AI enabled in your account
 * - Microsoft Entra ID tenant ID (for security integration)
 *
 * WARNING: NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (informational - warns but does not block)
-- ============================================================================

SELECT
    TO_DATE('2026-04-01') AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-04-01')) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-04-01')) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-04-01')) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-04-01')) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-04-01')) || ' days remaining'
    END AS demo_status;

-- ============================================================================
-- 1. SETUP CONTEXT
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- 2. CREATE DATABASE (if not exists)
-- ============================================================================

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION (Expires: 2026-04-01)';

-- ============================================================================
-- 3. CREATE SCHEMA
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI
    COMMENT = 'DEMO: teams-agent-uni - Cortex Agents for Microsoft Teams & M365 Copilot (Expires: 2026-04-01)';

-- ============================================================================
-- 4. CREATE WAREHOUSE
-- ============================================================================

CREATE WAREHOUSE IF NOT EXISTS SFE_TEAMS_AGENT_UNI_WH WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'DEMO: teams-agent-uni - Compute for Cortex Agent queries (Expires: 2026-04-01)';

-- ============================================================================
-- 5. SET CONTEXT
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA TEAMS_AGENT_UNI;
USE WAREHOUSE SFE_TEAMS_AGENT_UNI_WH;

-- ============================================================================
-- 6. CREATE AI JOKE GENERATION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION GENERATE_SAFE_JOKE(subject VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: teams-agent-uni - Generate safe-for-work jokes using AI_COMPLETE with Cortex Guard (Expires: 2026-04-01)'
AS
$$
  SELECT AI_COMPLETE(
    'mistral-large2',
    [
      {
        'role': 'system',
        'content': 'You are a professional comedian who specializes in clean, workplace-appropriate humor. Your jokes should be:
- Safe for work (no profanity, sexual content, or offensive material)
- Brief (2-3 sentences maximum)
- Clever and witty
- Relevant to the subject provided
- Family-friendly and inclusive'
      },
      {
        'role': 'user',
        'content': 'Tell me a funny, workplace-appropriate joke about: ' || subject
      }
    ],
    {
      'guardrails': true,
      'temperature': 0.7,
      'max_tokens': 150
    }
  ):choices[0]:messages::STRING
$$;

-- ============================================================================
-- 7. CREATE CORTEX AGENT (via DDL)
-- ============================================================================

CREATE OR REPLACE AGENT JOKE_ASSISTANT
    COMMENT = 'DEMO: teams-agent-uni - AI joke bot powered by Cortex Agent (Expires: 2026-04-01)'
    PROFILE = '{"display_name": "Joke Assistant", "color": "blue"}'
    FROM SPECIFICATION
    $$
    models:
      orchestration: auto

    orchestration:
      budget:
        seconds: 30
        tokens: 8000

    instructions:
      system: >
        You are a friendly, enthusiastic AI comedian specializing in tech humor.
        When users ask for a joke, always use the joke_generator tool with their
        requested subject. Keep responses brief and professional. If no subject is
        specified, ask the user what topic they would like a joke about.
      response: >
        When delivering jokes, keep it brief: just the joke followed by an
        invitation to try a different topic. If the tool returns a safety
        filter message, politely suggest a different topic.
      orchestration: >
        Extract the subject from the user message and call the joke_generator
        tool. If the user asks for multiple jokes, generate them one at a time.
      sample_questions:
        - question: "Tell me a joke about data engineers"
        - question: "Give me a joke about SQL databases"
        - question: "Make me laugh about cloud computing"
        - question: "Tell me something funny about Snowflake"

    tools:
      - tool_spec:
          type: "custom_tool"
          name: "joke_generator"
          description: >
            Generates safe, workplace-appropriate jokes about any subject using
            Snowflake Cortex AI with content safety guardrails. Pass the desired
            joke topic as the subject parameter.

    tool_resources:
      joke_generator:
        type: "function"
        identifier: "SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.GENERATE_SAFE_JOKE"
        execution_environment:
          type: "warehouse"
          warehouse: "SFE_TEAMS_AGENT_UNI_WH"
    $$;

-- ============================================================================
-- 8. CREATE SECURITY INTEGRATION FOR ENTRA ID
-- ============================================================================

-- REQUIRED: Replace YOUR_TENANT_ID with your Microsoft Entra ID tenant ID.
-- Find it: Azure Portal -> Microsoft Entra ID -> Overview -> Tenant ID
SET entra_tenant_id = 'YOUR_TENANT_ID';

SET external_oauth_issuer = 'https://login.microsoftonline.com/' || $entra_tenant_id || '/v2.0';
SET external_oauth_jws_keys_url = 'https://login.microsoftonline.com/' || $entra_tenant_id || '/discovery/v2.0/keys';

EXECUTE IMMEDIATE
  'CREATE OR REPLACE SECURITY INTEGRATION SFE_ENTRA_ID_CORTEX_AGENTS_INTEGRATION
     TYPE = EXTERNAL_OAUTH
     ENABLED = TRUE
     EXTERNAL_OAUTH_TYPE = AZURE
     EXTERNAL_OAUTH_ISSUER = ''' || $external_oauth_issuer || '''
     EXTERNAL_OAUTH_JWS_KEYS_URL = ''' || $external_oauth_jws_keys_url || '''
     EXTERNAL_OAUTH_AUDIENCE_LIST = (''5a840489-78db-4a42-8772-47be9d833efe'')
     EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = (''email'', ''upn'')
     EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = ''EMAIL_ADDRESS''
     EXTERNAL_OAUTH_ANY_ROLE_MODE = ''ENABLE''
     COMMENT = ''DEMO: teams-agent-uni - OAuth integration for Microsoft Teams (Expires: 2026-04-01)'';';

-- ============================================================================
-- 9. GRANT PERMISSIONS
-- ============================================================================

GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI TO ROLE PUBLIC;
GRANT USAGE ON WAREHOUSE SFE_TEAMS_AGENT_UNI_WH TO ROLE PUBLIC;
GRANT USAGE ON FUNCTION SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.GENERATE_SAFE_JOKE(VARCHAR) TO ROLE PUBLIC;
GRANT USAGE ON AGENT SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.JOKE_ASSISTANT TO ROLE PUBLIC;

-- ============================================================================
-- 10. VERIFICATION
-- ============================================================================

SHOW AGENTS IN SCHEMA SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI;
SHOW USER FUNCTIONS LIKE 'GENERATE_SAFE_JOKE';

SELECT AI_COMPLETE(
    'mistral-large2',
    'Tell a one-line joke about Snowflake databases',
    {}
) AS smoke_test;

SELECT
    'Deployment complete' AS status,
    CURRENT_DATABASE() AS database,
    CURRENT_SCHEMA() AS schema,
    CURRENT_WAREHOUSE() AS warehouse,
    '2026-04-01' AS expires;

/*******************************************************************************
 * POST-DEPLOYMENT STEPS:
 *
 * 1. SECURITY INTEGRATION:
 *    - Replace YOUR_TENANT_ID above with your Microsoft Entra ID tenant ID
 *    - Re-run the security integration section
 *    - Verify: DESCRIBE SECURITY INTEGRATION SFE_ENTRA_ID_CORTEX_AGENTS_INTEGRATION;
 *
 * 2. ENTRA ID CONSENT (requires Azure Global Administrator):
 *    - Grant consent for OAuth Resource app:
 *      https://login.microsoftonline.com/<tenant-id>/adminconsent?client_id=5a840489-78db-4a42-8772-47be9d833efe
 *    - Grant consent for OAuth Client app:
 *      https://login.microsoftonline.com/<tenant-id>/adminconsent?client_id=bfdfa2a2-bce5-4aee-ad3d-41ef70eb5086
 *    - See docs/02-ENTRA-ID-SETUP.md for detailed steps
 *
 * 3. INSTALL TEAMS APP:
 *    - Search "Snowflake Cortex Agents" in Microsoft AppSource or Teams store
 *    - Connect your Snowflake account
 *    - Select Joke Assistant agent
 *    - See docs/03-INSTALL-TEAMS-APP.md
 *
 * CLEANUP:
 *    Run teardown_all.sql to remove all demo objects
 ******************************************************************************/
