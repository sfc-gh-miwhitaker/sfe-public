/*
Snowflake MCP Role Controls - Validation queries
Pair-programmed by SE Community + Cortex Code

Run administrative checks in Snowsight. Run session-context checks through a
temporary, tightly controlled MCP SQL diagnostic tool when end-to-end proof is
required, then remove that diagnostic tool.
*/

USE ROLE ACCOUNTADMIN;

DESCRIBE SECURITY INTEGRATION MCP_OAUTH_INTEGRATION;

SHOW USERS LIKE 'MCP_USER';

SELECT
    "name" AS user_name,
    "default_role" AS default_role,
    "default_secondary_roles" AS default_secondary_roles,
    "default_warehouse" AS default_warehouse
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

DESCRIBE SESSION POLICY SNOWFLAKE_EXAMPLE.SECURITY_POLICIES.MCP_SECONDARY_ROLE_POLICY;

SELECT
    policy_name,
    policy_kind,
    ref_entity_name,
    ref_entity_domain
FROM TABLE(
    SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.POLICY_REFERENCES(
        POLICY_NAME => 'SNOWFLAKE_EXAMPLE.SECURITY_POLICIES.MCP_SECONDARY_ROLE_POLICY'
    )
);

SHOW GRANTS TO ROLE MCP_ACCESS_ROLE;

-- Execute these through the MCP session, not the administrator's worksheet.
SELECT
    CURRENT_USER() AS current_user,
    CURRENT_ROLE() AS current_primary_role,
    CURRENT_SECONDARY_ROLES() AS current_secondary_roles,
    IS_ROLE_IN_SESSION('MCP_ACCESS_ROLE') AS mcp_access_role_active,
    IS_ROLE_IN_SESSION('MCP_ANALYST_ROLE') AS mcp_analyst_role_active,
    IS_ROLE_IN_SESSION('MCP_SEARCH_ROLE') AS mcp_search_role_active,
    IS_ROLE_IN_SESSION('SYSADMIN') AS sysadmin_active;
