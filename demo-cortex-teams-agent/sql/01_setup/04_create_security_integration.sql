/*==============================================================================
Create Entra ID OAuth Security Integration
teams-agent-uni | Expires: 2026-04-01

Creates: SFE_ENTRA_ID_CORTEX_AGENTS_INTEGRATION
Depends: Microsoft Entra ID tenant with consent granted for BOTH apps
         (see docs/02-ENTRA-ID-SETUP.md)

Reference: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-teams-integration
==============================================================================*/

-- ============================================================================
-- STEP 1: SET YOUR TENANT ID
-- ============================================================================

-- REQUIRED: Replace with your Microsoft Entra ID tenant ID.
-- Find it: Azure Portal -> Microsoft Entra ID -> Overview -> Tenant ID
-- Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
SET entra_tenant_id = 'YOUR_TENANT_ID';

SET external_oauth_issuer = 'https://login.microsoftonline.com/' || $entra_tenant_id || '/v2.0';
SET external_oauth_jws_keys_url = 'https://login.microsoftonline.com/' || $entra_tenant_id || '/discovery/v2.0/keys';

-- ============================================================================
-- STEP 2: CREATE SECURITY INTEGRATION
-- ============================================================================

USE ROLE ACCOUNTADMIN;

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
-- VERIFICATION
-- ============================================================================

DESCRIBE SECURITY INTEGRATION SFE_ENTRA_ID_CORTEX_AGENTS_INTEGRATION;

/*
 * PARAMETER REFERENCE:
 *
 * EXTERNAL_OAUTH_AUDIENCE_LIST = '5a840489-78db-4a42-8772-47be9d833efe'
 *   Fixed application ID for Cortex Agents Bot OAuth Resource.
 *
 * EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = ('email', 'upn')
 *   JWT claims used to map Entra ID users to Snowflake users.
 *   Tries email first, falls back to UPN.
 *
 * EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'EMAIL_ADDRESS'
 *   Snowflake user property matched against the JWT claim.
 *   Alternative: set to 'LOGIN_NAME' and use 'upn' claim only.
 *
 * EXTERNAL_OAUTH_ANY_ROLE_MODE = 'ENABLE'
 *   Allows the user's default Snowflake role to be used.
 *   Required for Cortex Agents Teams integration.
 *
 * TROUBLESHOOTING:
 *   390303 (Invalid OAuth token)  -> Check tenant ID in issuer/keys URLs
 *   390304 (User mapping failed)  -> Verify EMAIL_ADDRESS matches Entra UPN/email
 *   390317 (Role not in token)    -> Ensure ANY_ROLE_MODE = 'ENABLE'
 *   390186 (Role not granted)     -> Check BLOCKED_ROLES_LIST doesn't include default role
 */
