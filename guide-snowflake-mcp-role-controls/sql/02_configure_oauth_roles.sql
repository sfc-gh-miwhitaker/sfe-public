/*
Snowflake MCP Role Controls - Recommended Snowflake OAuth configuration
Pair-programmed by SE Community + Cortex Code

This script configures an existing custom-client OAuth integration.
Reconnect the MCP client after applying the changes.
*/

USE ROLE ACCOUNTADMIN;

-- Secondary roles must be NONE before an OAuth role allowlist can be set.
ALTER SECURITY INTEGRATION MCP_OAUTH_INTEGRATION
  SET OAUTH_USE_SECONDARY_ROLES = NONE;

ALTER SECURITY INTEGRATION MCP_OAUTH_INTEGRATION
  SET ALLOWED_ROLES_LIST = ('MCP_ACCESS_ROLE')
      OAUTH_ENABLE_ROLE_SELECTION = FALSE
      OAUTH_ANY_ROLE_MODE = DISABLE;

-- Required when this user previously consented through role selection.
-- This revokes existing tokens and forces authorization again.
ALTER USER MCP_USER
  REMOVE DELEGATED AUTHORIZATIONS
  FROM SECURITY INTEGRATION MCP_OAUTH_INTEGRATION;

-- Optional: advertise the named primary role to clients that honor it.
ALTER SCHEMA MCP_DB.MCP_SCHEMA
  SET OAUTH_SCOPES_SUPPORTED = 'session:role:MCP_ACCESS_ROLE';

DESCRIBE SECURITY INTEGRATION MCP_OAUTH_INTEGRATION;
