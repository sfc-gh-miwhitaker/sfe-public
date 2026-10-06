/*
Snowflake MCP Role Controls - Exception pattern for selected secondary roles
Pair-programmed by SE Community + Cortex Code

Use this pattern instead of the recommended single-role configuration only when
the MCP workload requires privileges split across existing roles. Review and
preserve every setting in the effective account or user session policy before
attaching a replacement policy.
*/

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'Shared database for Snowflake example projects';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SECURITY_POLICIES
  COMMENT = 'Session and access policy definitions';

CREATE OR REPLACE SESSION POLICY SNOWFLAKE_EXAMPLE.SECURITY_POLICIES.MCP_SECONDARY_ROLE_POLICY
  ALLOWED_SECONDARY_ROLES = (MCP_ANALYST_ROLE, MCP_SEARCH_ROLE)
  BLOCKED_SECONDARY_ROLES = (SYSADMIN)
  COMMENT = 'Limits secondary roles available to designated MCP users';

-- STOP: inventory existing session policies and use POLICY_REFERENCES for each
-- candidate policy before attachment. A user-level policy overrides the account
-- policy, so preserve the effective policy's other controls.
SHOW SESSION POLICIES IN ACCOUNT;

-- After preserving existing timeout, lifespan, and agent-scope settings:
-- ALTER USER MCP_USER SET SESSION POLICY
--   SNOWFLAKE_EXAMPLE.SECURITY_POLICIES.MCP_SECONDARY_ROLE_POLICY;

-- Create a separate integration for this exception pattern. Snowflake does not
-- document an ALTER operation that clears an existing ALLOWED_ROLES_LIST.
CREATE SECURITY INTEGRATION MCP_MULTI_ROLE_OAUTH_INTEGRATION
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = '<MCP_CLIENT_CALLBACK_URI>'
  OAUTH_USE_SECONDARY_ROLES = IMPLICIT
  OAUTH_ENABLE_ROLE_SELECTION = FALSE
  OAUTH_ANY_ROLE_MODE = DISABLE
  IS_AGENTIC = TRUE
  COMMENT = 'OAuth integration for the reviewed multi-role MCP exception';

-- Reconnect the MCP client so a new OAuth session uses this configuration.
