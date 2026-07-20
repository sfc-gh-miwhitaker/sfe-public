/*==============================================================================
  GUIDE: Power BI + Snowflake OAuth
  Snowflake Setup — Block A (OAuth) + Block B (SCIM)
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-19

  Run this entire file in Snowsight as ACCOUNTADMIN.
  One substitution required: replace <YOUR_ENTRA_TENANT_ID> in Block A.
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- BLOCK A: Tell Snowflake to trust Microsoft logins
-- Replace <YOUR_ENTRA_TENANT_ID> with your Entra Tenant ID.
-- The trailing / on the issuer URL is REQUIRED.
-- Everything else: leave exactly as written.
-- ============================================================
CREATE SECURITY INTEGRATION powerbi
    TYPE                                            = external_oauth
    ENABLED                                         = true
    EXTERNAL_OAUTH_TYPE                             = azure
    EXTERNAL_OAUTH_ISSUER                           = 'https://sts.windows.net/<YOUR_ENTRA_TENANT_ID>/'
    EXTERNAL_OAUTH_JWS_KEYS_URL                     = 'https://login.windows.net/common/discovery/keys'
    EXTERNAL_OAUTH_AUDIENCE_LIST                    = (
        'https://analysis.windows.net/powerbi/connector/Snowflake',
        'https://analysis.windows.net/powerbi/connector/snowflake'
    )
    EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM         = 'upn'
    EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'login_name';


-- ============================================================
-- BLOCK B: Allow Microsoft Entra to sync users automatically (SCIM)
-- No substitutions needed.
-- ============================================================
CREATE ROLE IF NOT EXISTS aad_provisioner;
GRANT CREATE USER ON ACCOUNT TO ROLE aad_provisioner;
GRANT CREATE ROLE ON ACCOUNT TO ROLE aad_provisioner;
GRANT ROLE aad_provisioner TO ROLE accountadmin;

CREATE OR REPLACE SECURITY INTEGRATION aad_provisioning
    TYPE        = scim
    SCIM_CLIENT = 'azure'
    RUN_AS_ROLE = 'AAD_PROVISIONER';


-- ============================================================
-- GENERATE SCIM TOKEN
-- The Microsoft tutorial (Step 2) asks for a "Secret Token".
-- Run this and copy the result — you'll paste it into Microsoft's setup.
-- It won't be shown again after you close this result.
-- ============================================================
SELECT SYSTEM$GENERATE_SCIM_ACCESS_TOKEN('AAD_PROVISIONING');


-- ============================================================
-- VERIFY: Both integrations should appear in this list
-- ============================================================
SHOW INTEGRATIONS;


-- ============================================================
-- OPTIONAL: Azure Government cloud — replace Block A with this
-- ============================================================
-- CREATE SECURITY INTEGRATION powerbi_gov
--     TYPE                                            = external_oauth
--     ENABLED                                         = true
--     EXTERNAL_OAUTH_TYPE                             = azure
--     EXTERNAL_OAUTH_ISSUER                           = 'https://sts.windows.net/<YOUR_ENTRA_TENANT_ID>/'
--     EXTERNAL_OAUTH_JWS_KEYS_URL                     = 'https://login.windows.net/common/discovery/keys'
--     EXTERNAL_OAUTH_AUDIENCE_LIST                    = (
--         'https://analysis.usgovcloudapi.net/powerbi/connector/Snowflake',
--         'https://analysis.usgovcloudapi.net/powerbi/connector/snowflake'
--     )
--     EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM         = 'upn'
--     EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'login_name';


-- ============================================================
-- OPTIONAL: Enable secondary roles in Power BI sessions
-- ============================================================
-- ALTER SECURITY INTEGRATION powerbi
--     SET EXTERNAL_OAUTH_ANY_ROLE_MODE = ENABLE;
