/*==============================================================================
02_BRONZE / 01_NETWORK_AND_AUTH
External Access Integration for QuickBooks Online OAuth 2.0
Author: SE Community | Expires: 2026-03-29

Requires ACCOUNTADMIN for security integration + network rule.
After running, switch back to SYSADMIN for the rest of the demo.
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- 1. Network Rule: allow egress to QuickBooks API hosts
-------------------------------------------------------------------------------
CREATE OR REPLACE NETWORK RULE SFE_QBO_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = (
        'sandbox-quickbooks.api.intuit.com',
        'quickbooks.api.intuit.com',
        'oauth.platform.intuit.com'
    )
    COMMENT = 'DEMO: Egress to QuickBooks Online REST API and OAuth token endpoint (Expires: 2026-03-29)';

-------------------------------------------------------------------------------
-- 2. Security Integration: OAuth 2.0 for Intuit/QBO
--    Replace client_id / client_secret with your Intuit Developer app values.
-------------------------------------------------------------------------------
CREATE OR REPLACE SECURITY INTEGRATION SFE_QBO_OAUTH_INTEGRATION
    TYPE = API_AUTHENTICATION
    AUTH_TYPE = OAUTH2
    OAUTH_CLIENT_ID = '<YOUR_INTUIT_CLIENT_ID>'
    OAUTH_CLIENT_SECRET = '<YOUR_INTUIT_CLIENT_SECRET>'
    OAUTH_TOKEN_ENDPOINT = 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'
    OAUTH_AUTHORIZATION_ENDPOINT = 'https://appcenter.intuit.com/connect/oauth2'
    OAUTH_ALLOWED_SCOPES = ('com.intuit.quickbooks.accounting')
    ENABLED = TRUE
    COMMENT = 'DEMO: QBO OAuth2 security integration (Expires: 2026-03-29)';

-------------------------------------------------------------------------------
-- 3. Secret: stores OAuth refresh token (managed by Snowflake)
--    After creating, use SYSTEM$START_OAUTH_FLOW / SYSTEM$FINISH_OAUTH_FLOW
--    to complete the consent and populate the refresh token.
-------------------------------------------------------------------------------
CREATE OR REPLACE SECRET SFE_QBO_OAUTH_SECRET
    TYPE = OAUTH2
    API_AUTHENTICATION = SFE_QBO_OAUTH_INTEGRATION
    COMMENT = 'DEMO: QBO OAuth2 refresh token (Expires: 2026-03-29)';

-- To populate the secret with a refresh token:
-- CALL SYSTEM$START_OAUTH_FLOW('SNOWFLAKE_EXAMPLE.QB_API.SFE_QBO_OAUTH_SECRET');
-- (visit the URL, complete consent, copy query params from redirect)
-- CALL SYSTEM$FINISH_OAUTH_FLOW('state=...');

-------------------------------------------------------------------------------
-- 4. External Access Integration: ties network rule + secret together
-------------------------------------------------------------------------------
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SFE_QBO_API_INTEGRATION
    ALLOWED_NETWORK_RULES = (SFE_QBO_NETWORK_RULE)
    ALLOWED_AUTHENTICATION_SECRETS = (SFE_QBO_OAUTH_SECRET)
    ENABLED = TRUE
    COMMENT = 'DEMO: External access for QuickBooks API calls (Expires: 2026-03-29)';

-------------------------------------------------------------------------------
-- 5. Grant usage to SYSADMIN so stored procedures can reference these objects
-------------------------------------------------------------------------------
GRANT READ ON SECRET SFE_QBO_OAUTH_SECRET TO ROLE SYSADMIN;
GRANT USAGE ON INTEGRATION SFE_QBO_API_INTEGRATION TO ROLE SYSADMIN;

USE ROLE SYSADMIN;
