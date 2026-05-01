/*==============================================================================
Grant Permissions for Cortex Agent Access
teams-agent-uni | Expires: 2026-05-01

Grants: PUBLIC access to database, schema, warehouse, function, and agent
Depends: All previous setup scripts (01-04)

Reference: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- OPTION 1: GRANT TO PUBLIC (Demo - broadest access)
-- ============================================================================

GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI TO ROLE PUBLIC;
GRANT USAGE ON WAREHOUSE SFE_TEAMS_AGENT_UNI_WH TO ROLE PUBLIC;
GRANT USAGE ON FUNCTION SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.GENERATE_SAFE_JOKE(VARCHAR) TO ROLE PUBLIC;
GRANT USAGE ON AGENT SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.JOKE_ASSISTANT TO ROLE PUBLIC;

-- ============================================================================
-- OPTION 2: GRANT TO SPECIFIC ROLE (Production pattern)
-- ============================================================================

/*
CREATE ROLE IF NOT EXISTS CORTEX_AGENT_USERS
    COMMENT = 'Users authorized to interact with Cortex Agents in Teams';

GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE CORTEX_AGENT_USERS;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI TO ROLE CORTEX_AGENT_USERS;
GRANT USAGE ON WAREHOUSE SFE_TEAMS_AGENT_UNI_WH TO ROLE CORTEX_AGENT_USERS;
GRANT USAGE ON FUNCTION SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.GENERATE_SAFE_JOKE(VARCHAR)
    TO ROLE CORTEX_AGENT_USERS;
GRANT USAGE ON AGENT SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.JOKE_ASSISTANT
    TO ROLE CORTEX_AGENT_USERS;

GRANT ROLE CORTEX_AGENT_USERS TO USER <username>;
ALTER USER <username> SET DEFAULT_SECONDARY_ROLES = ('ALL');
*/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SHOW GRANTS ON DATABASE SNOWFLAKE_EXAMPLE;
SHOW GRANTS ON AGENT SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.JOKE_ASSISTANT;

/*
 * IMPORTANT - DEFAULT ROLE CONFIGURATION:
 *
 * The Teams integration uses each user's DEFAULT ROLE. Ensure it has the
 * necessary privileges. Use secondary roles to avoid changing the primary:
 *
 *   GRANT ROLE CORTEX_AGENT_USERS TO USER alice;
 *   ALTER USER alice SET DEFAULT_SECONDARY_ROLES = ('ALL');
 *
 * NETWORK POLICY NOTES (March 2026):
 * Network policies ARE supported with two caveats:
 *   1. IP from Entra ID can be stale -- user may need to re-login
 *   2. IPv6 addresses from Entra ID not yet supported by Snowflake
 * Private Link is NOT supported.
 * Docs: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-teams-integration#network-policies
 * Troubleshooting: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-teams-integration#network-policy-issues
 */
