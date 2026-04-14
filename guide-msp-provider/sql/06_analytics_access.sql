/*==============================================================================
CUSTOMER ANALYTICS ACCESS -- MSP Provider Guide
Run as MSP_PLATFORM_ENGINEER in the relevant customer account.
See Part 7 of README.md for architectural context and ToS analysis.

Options:
  A.  Data Sharing       — explicit §1.4(a) carveout, customer receives share
  B-BI. BI Service Acct  — PowerBI gateway, key-pair auth, no Snowsight
  B1. Snowsight User     — SI product, human login, MFA + CLIENT_TYPES
  B2. API-Only User      — Cortex Analyst REST API, service account, no Snowsight
  C.  Embedded           — no SQL here; MSP backend calls Cortex Analyst API
  D1. Managed MCP Server — CREATE MCP SERVER + OAuth, AI client access
  D2. Client-Side MCP    — reuses B2 service account with local MCP server / CoCo CLI
  D3. MSP-Mediated MCP   — no SQL here; MSP runs MCP server in own infra

IMPORTANT:
  - CLIENT_TYPES is best-effort and does NOT restrict REST API access.
  - MFA_ENROLLMENT = REQUIRED forces CLIENT_TYPES to include SNOWFLAKE_UI.
  - TYPE = SERVICE users cannot log into Snowsight regardless of CLIENT_TYPES.
  - The network policy is your primary security boundary, not CLIENT_TYPES.

Set the parameters in Section 0, then execute the block for your chosen option.
==============================================================================*/

----------------------------------------------------------------------
-- 0. Parameters — change these per customer
----------------------------------------------------------------------
SET cust_name          = 'CUST_ACME';           -- uppercase, no spaces, matches account prefix
SET cust_sf_account    = '<CUST_SNOWFLAKE_ACCT_IDENTIFIER>'; -- for Option A only
SET bi_gateway_ip      = '0.0.0.0/32';          -- Option B-BI: PowerBI on-prem gateway IP
SET si_office_cidr     = '203.0.113.0/24';      -- Option B1: customer office or VPN CIDR
SET si_user_email      = '<USER_EMAIL>';         -- Option B1: customer SI user email
SET api_server_ip      = '0.0.0.0/32';          -- Option B2 / D2: customer app server IP
SET mcp_user_email     = '<USER_EMAIL>';         -- Option D1: customer MCP/AI client user email
SET mcp_redirect_uri   = '<AI_CLIENT_REDIRECT_URI>'; -- Option D1: AI client OAuth redirect URI

----------------------------------------------------------------------
-- A. DATA SHARING
-- ToS §1.4(a) explicit carveout. No MSP-account credentials issued.
-- Customer receives a share and connects their own tooling to it.
----------------------------------------------------------------------

USE ROLE MSP_PLATFORM_ENGINEER;

CREATE SHARE IF NOT EXISTS IDENTIFIER($cust_name || '_ANALYTICS_SHARE')
    COMMENT = $cust_name || ' analytics share — PRESENTATION.ANALYTICS views only';

GRANT USAGE ON DATABASE PRESENTATION
    TO SHARE IDENTIFIER($cust_name || '_ANALYTICS_SHARE');
GRANT USAGE ON SCHEMA PRESENTATION.ANALYTICS
    TO SHARE IDENTIFIER($cust_name || '_ANALYTICS_SHARE');
GRANT SELECT ON ALL VIEWS IN SCHEMA PRESENTATION.ANALYTICS
    TO SHARE IDENTIFIER($cust_name || '_ANALYTICS_SHARE');

-- Option A1: customer has their own Snowflake account
ALTER SHARE IDENTIFIER($cust_name || '_ANALYTICS_SHARE')
    ADD ACCOUNTS = IDENTIFIER($cust_sf_account);

-- Option A2: customer does not have a Snowflake account — provision a reader account
-- NOTE: Reader accounts cannot run Snowflake Intelligence.
-- Uncomment when needed. Returns a locator; use that locator to ADD ACCOUNTS above.
/*
CREATE MANAGED ACCOUNT IDENTIFIER($cust_name || '_READER_ACCOUNT')
    ADMIN_NAME     = reader_admin
    ADMIN_PASSWORD = '<YOUR_READER_ADMIN_PASSWORD>'
    TYPE           = READER;
*/

----------------------------------------------------------------------
-- B-BI. POWERBI SERVICE ACCOUNT
-- Gate 1 triggered (read-only). Service account, key-pair auth, no MFA.
-- Network policy restricts to the PowerBI on-premises gateway IP.
-- ToS §1.1 — service account as Contractor of the MSP.
----------------------------------------------------------------------

USE ROLE MSP_PLATFORM_ENGINEER;

CREATE ROLE IF NOT EXISTS IDENTIFIER($cust_name || '_BI_READONLY')
    COMMENT = $cust_name || ' BI read-only — SELECT on PRESENTATION.ANALYTICS only';

GRANT USAGE ON DATABASE PRESENTATION
    TO ROLE IDENTIFIER($cust_name || '_BI_READONLY');
GRANT USAGE ON SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_BI_READONLY');
GRANT SELECT ON ALL VIEWS IN SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_BI_READONLY');
GRANT SELECT ON FUTURE VIEWS IN SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_BI_READONLY');
GRANT USAGE ON WAREHOUSE CUST_ANALYTICS_WH
    TO ROLE IDENTIFIER($cust_name || '_BI_READONLY');

GRANT ROLE IDENTIFIER($cust_name || '_BI_READONLY') TO ROLE MSP_PLATFORM_ENGINEER;

CREATE NETWORK RULE IF NOT EXISTS IDENTIFIER($cust_name || '_BI_INGRESS_RULE')
    MODE       = INGRESS
    TYPE       = IPV4
    VALUE_LIST = ($bi_gateway_ip)
    COMMENT    = $cust_name || ' BI gateway ingress rule';

CREATE NETWORK POLICY IF NOT EXISTS IDENTIFIER($cust_name || '_BI_NETWORK_POLICY')
    ALLOWED_NETWORK_RULE_LIST = (IDENTIFIER($cust_name || '_BI_INGRESS_RULE'));

CREATE USER IF NOT EXISTS IDENTIFIER($cust_name || '_BI_SVC')
    DEFAULT_ROLE = IDENTIFIER($cust_name || '_BI_READONLY')
    TYPE         = SERVICE
    COMMENT      = $cust_name || ' PowerBI connector service account — key-pair auth only';

ALTER USER IDENTIFIER($cust_name || '_BI_SVC')
    SET NETWORK_POLICY = IDENTIFIER($cust_name || '_BI_NETWORK_POLICY');

GRANT ROLE IDENTIFIER($cust_name || '_BI_READONLY')
    TO USER IDENTIFIER($cust_name || '_BI_SVC');

-- Set RSA public key after generating key pair externally:
-- ALTER USER IDENTIFIER($cust_name || '_BI_SVC') SET RSA_PUBLIC_KEY = '<PUBLIC_KEY>';

----------------------------------------------------------------------
-- B1. SNOWFLAKE INTELLIGENCE — SNOWSIGHT HUMAN USERS
-- Gate 1 triggered (read-only). Human login to Snowsight.
-- MFA required. CLIENT_TYPES = SNOWFLAKE_UI (best-effort — does NOT block REST APIs).
-- Network policy is the real security boundary.
-- SNOWFLAKE.CORTEX_USER grants access to all Cortex AI features.
-- ToS §1.1 — human users as Contractors of the MSP.
--
-- CATCH-22: MFA_ENROLLMENT = REQUIRED forces CLIENT_TYPES to include
-- SNOWFLAKE_UI because Snowsight is the only place users can enroll in MFA.
----------------------------------------------------------------------

USE ROLE MSP_PLATFORM_ENGINEER;

CREATE ROLE IF NOT EXISTS IDENTIFIER($cust_name || '_SI_READONLY')
    COMMENT = $cust_name || ' Snowflake Intelligence — SELECT + CORTEX_USER, no write access';

GRANT USAGE ON DATABASE PRESENTATION
    TO ROLE IDENTIFIER($cust_name || '_SI_READONLY');
GRANT USAGE ON SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_SI_READONLY');
GRANT SELECT ON ALL VIEWS IN SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_SI_READONLY');
GRANT SELECT ON FUTURE VIEWS IN SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_SI_READONLY');
GRANT USAGE ON WAREHOUSE CUST_ANALYTICS_WH
    TO ROLE IDENTIFIER($cust_name || '_SI_READONLY');

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER
    TO ROLE IDENTIFIER($cust_name || '_SI_READONLY');

GRANT ROLE IDENTIFIER($cust_name || '_SI_READONLY') TO ROLE MSP_PLATFORM_ENGINEER;

CREATE NETWORK RULE IF NOT EXISTS IDENTIFIER($cust_name || '_SI_INGRESS_RULE')
    MODE       = INGRESS
    TYPE       = IPV4
    VALUE_LIST = ($si_office_cidr)
    COMMENT    = $cust_name || ' SI user ingress rule — customer office/VPN';

CREATE NETWORK POLICY IF NOT EXISTS IDENTIFIER($cust_name || '_SI_NETWORK_POLICY')
    ALLOWED_NETWORK_RULE_LIST = (IDENTIFIER($cust_name || '_SI_INGRESS_RULE'));

-- Auth policy: MFA required, Snowsight only.
-- CLIENT_TYPES must include SNOWFLAKE_UI when MFA_ENROLLMENT = REQUIRED.
CREATE AUTHENTICATION POLICY IF NOT EXISTS IDENTIFIER($cust_name || '_SI_AUTH_POLICY')
    MFA_ENROLLMENT = 'REQUIRED'
    CLIENT_TYPES   = ('SNOWFLAKE_UI')
    COMMENT        = $cust_name || ' SI human users — MFA + Snowsight only';

CREATE USER IF NOT EXISTS IDENTIFIER($cust_name || '_SI_USER_1')
    DEFAULT_ROLE         = IDENTIFIER($cust_name || '_SI_READONLY')
    EMAIL                = $si_user_email
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT              = $cust_name || ' Snowflake Intelligence user';

ALTER USER IDENTIFIER($cust_name || '_SI_USER_1')
    SET NETWORK_POLICY       = IDENTIFIER($cust_name || '_SI_NETWORK_POLICY');
ALTER USER IDENTIFIER($cust_name || '_SI_USER_1')
    SET AUTHENTICATION POLICY = IDENTIFIER($cust_name || '_SI_AUTH_POLICY');

GRANT ROLE IDENTIFIER($cust_name || '_SI_READONLY')
    TO USER IDENTIFIER($cust_name || '_SI_USER_1');

----------------------------------------------------------------------
-- B2. CORTEX ANALYST API — SERVICE ACCOUNT, NO SNOWSIGHT
-- Gate 1 triggered (read-only). Service account calls REST API.
-- CLIENT_TYPES = DRIVERS blocks Snowsight (best-effort).
-- TYPE = SERVICE means no password auth — Snowsight login is impossible anyway.
-- CORTEX_ANALYST_USER (not CORTEX_USER) — limits to Analyst only.
-- Network policy restricts to customer's application server IP.
--
-- This is the middle ground between B1 (full Snowsight) and C (MSP builds all).
-- The customer owns the UI; the MSP owns the data and account.
----------------------------------------------------------------------

USE ROLE MSP_PLATFORM_ENGINEER;

CREATE ROLE IF NOT EXISTS IDENTIFIER($cust_name || '_API_READONLY')
    COMMENT = $cust_name || ' Cortex Analyst API — SELECT + CORTEX_ANALYST_USER, no Snowsight';

GRANT USAGE ON DATABASE PRESENTATION
    TO ROLE IDENTIFIER($cust_name || '_API_READONLY');
GRANT USAGE ON SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_API_READONLY');
GRANT SELECT ON ALL VIEWS IN SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_API_READONLY');
GRANT SELECT ON FUTURE VIEWS IN SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_API_READONLY');
GRANT USAGE ON WAREHOUSE CUST_ANALYTICS_WH
    TO ROLE IDENTIFIER($cust_name || '_API_READONLY');

-- CORTEX_ANALYST_USER — narrower than CORTEX_USER, Analyst API only
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_ANALYST_USER
    TO ROLE IDENTIFIER($cust_name || '_API_READONLY');

GRANT ROLE IDENTIFIER($cust_name || '_API_READONLY') TO ROLE MSP_PLATFORM_ENGINEER;

CREATE NETWORK RULE IF NOT EXISTS IDENTIFIER($cust_name || '_API_INGRESS_RULE')
    MODE       = INGRESS
    TYPE       = IPV4
    VALUE_LIST = ($api_server_ip)
    COMMENT    = $cust_name || ' API service — customer app server IP';

CREATE NETWORK POLICY IF NOT EXISTS IDENTIFIER($cust_name || '_API_NETWORK_POLICY')
    ALLOWED_NETWORK_RULE_LIST = (IDENTIFIER($cust_name || '_API_INGRESS_RULE'));

-- Auth policy: block Snowsight, allow drivers/connectors only.
-- No MFA_ENROLLMENT — we are blocking the UI enrollment path.
CREATE AUTHENTICATION POLICY IF NOT EXISTS IDENTIFIER($cust_name || '_API_AUTH_POLICY')
    CLIENT_TYPES = ('DRIVERS')
    COMMENT      = $cust_name || ' API-only — no Snowsight (best-effort)';

CREATE USER IF NOT EXISTS IDENTIFIER($cust_name || '_API_SVC')
    DEFAULT_ROLE = IDENTIFIER($cust_name || '_API_READONLY')
    TYPE         = SERVICE
    COMMENT      = $cust_name || ' Cortex Analyst API service account — key-pair only';

ALTER USER IDENTIFIER($cust_name || '_API_SVC')
    SET NETWORK_POLICY       = IDENTIFIER($cust_name || '_API_NETWORK_POLICY');
ALTER USER IDENTIFIER($cust_name || '_API_SVC')
    SET AUTHENTICATION POLICY = IDENTIFIER($cust_name || '_API_AUTH_POLICY');

GRANT ROLE IDENTIFIER($cust_name || '_API_READONLY')
    TO USER IDENTIFIER($cust_name || '_API_SVC');

-- Set RSA public key after generating key pair externally:
-- ALTER USER IDENTIFIER($cust_name || '_API_SVC') SET RSA_PUBLIC_KEY = '<PUBLIC_KEY>';

----------------------------------------------------------------------
-- D1. SNOWFLAKE-MANAGED MCP SERVER + OAUTH
-- Gate 1 triggered (read-only). Customer authenticates via OAuth in
-- their AI client (Claude.ai, ChatGPT, etc.). AI client calls MCP
-- tools exposed by a CREATE MCP SERVER object in the MSP account.
--
-- CRITICAL: OAUTH_USE_SECONDARY_ROLES = IMPLICIT activates the user's
-- DEFAULT_SECONDARY_ROLES (which defaults to ('ALL') for new users).
-- If DEFAULT_SECONDARY_ROLES is not restricted, all granted roles
-- activate and the AI client inherits the union of their privileges.
-- Grant ONLY the MCP readonly role AND set DEFAULT_SECONDARY_ROLES = ().
--
-- The managed MCP server only supports semantic views (not YAML files)
-- for the CORTEX_ANALYST_MESSAGE tool type.
----------------------------------------------------------------------

USE ROLE MSP_PLATFORM_ENGINEER;

CREATE MCP SERVER IF NOT EXISTS IDENTIFIER($cust_name || '_MCP_SERVER')
  FROM SPECIFICATION $$
    tools:
      - name: "customer-analytics"
        type: "CORTEX_ANALYST_MESSAGE"
        identifier: "PRESENTATION.ANALYTICS.CUST_ACME_SEMANTIC_VIEW"
        description: "Natural language analytics for customer data"
        title: "Customer Analytics"
  $$;

CREATE ROLE IF NOT EXISTS IDENTIFIER($cust_name || '_MCP_READONLY')
    COMMENT = $cust_name || ' MCP AI client — USAGE on MCP server + SELECT on semantic view';

GRANT USAGE ON DATABASE PRESENTATION
    TO ROLE IDENTIFIER($cust_name || '_MCP_READONLY');
GRANT USAGE ON SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_MCP_READONLY');
GRANT SELECT ON ALL VIEWS IN SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_MCP_READONLY');
GRANT SELECT ON FUTURE VIEWS IN SCHEMA PRESENTATION.ANALYTICS
    TO ROLE IDENTIFIER($cust_name || '_MCP_READONLY');
GRANT USAGE ON WAREHOUSE CUST_ANALYTICS_WH
    TO ROLE IDENTIFIER($cust_name || '_MCP_READONLY');

GRANT USAGE ON MCP SERVER IDENTIFIER($cust_name || '_MCP_SERVER')
    TO ROLE IDENTIFIER($cust_name || '_MCP_READONLY');
-- Semantic view grant (required for CORTEX_ANALYST_MESSAGE tool):
-- GRANT SELECT ON SEMANTIC VIEW PRESENTATION.ANALYTICS.<SEMANTIC_VIEW>
--     TO ROLE IDENTIFIER($cust_name || '_MCP_READONLY');

GRANT ROLE IDENTIFIER($cust_name || '_MCP_READONLY') TO ROLE MSP_PLATFORM_ENGINEER;

-- OAuth security integration — redirect URI is AI-client-specific.
-- Claude.ai:  https://claude.ai/api/mcp/auth_callback
-- Other clients: check client documentation for redirect URI.
CREATE SECURITY INTEGRATION IF NOT EXISTS IDENTIFIER($cust_name || '_MCP_OAUTH')
    TYPE = OAUTH
    OAUTH_CLIENT = CUSTOM
    ENABLED = TRUE
    OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
    OAUTH_REDIRECT_URI = $mcp_redirect_uri
    OAUTH_USE_SECONDARY_ROLES = IMPLICIT
    COMMENT = $cust_name || ' MCP OAuth — AI client access';

-- Retrieve client_id and client_secret for the AI client configuration:
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS(UPPER($cust_name) || '_MCP_OAUTH');

-- CRITICAL: grant ONLY the MCP readonly role to this user.
-- OAuth activates DEFAULT_SECONDARY_ROLES (defaults to ALL for new users).
-- Set DEFAULT_SECONDARY_ROLES = () to prevent role escalation.
CREATE USER IF NOT EXISTS IDENTIFIER($cust_name || '_MCP_USER')
    DEFAULT_ROLE = IDENTIFIER($cust_name || '_MCP_READONLY')
    EMAIL        = $mcp_user_email
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT      = $cust_name || ' MCP/AI client user — OAuth access only';

GRANT ROLE IDENTIFIER($cust_name || '_MCP_READONLY')
    TO USER IDENTIFIER($cust_name || '_MCP_USER');

ALTER USER IDENTIFIER($cust_name || '_MCP_USER')
    SET DEFAULT_SECONDARY_ROLES = ();

-- Network policy for MCP user (optional but recommended)
-- Lock to customer's known IP range if possible.
-- CREATE NETWORK RULE IF NOT EXISTS IDENTIFIER($cust_name || '_MCP_INGRESS_RULE')
--     MODE       = INGRESS
--     TYPE       = IPV4
--     VALUE_LIST = ($si_office_cidr);
-- CREATE NETWORK POLICY IF NOT EXISTS IDENTIFIER($cust_name || '_MCP_NETWORK_POLICY')
--     ALLOWED_NETWORK_RULE_LIST = (IDENTIFIER($cust_name || '_MCP_INGRESS_RULE'));
-- ALTER USER IDENTIFIER($cust_name || '_MCP_USER')
--     SET NETWORK_POLICY = IDENTIFIER($cust_name || '_MCP_NETWORK_POLICY');

----------------------------------------------------------------------
-- D2. CLIENT-SIDE MCP / CORTEX CODE CLI
-- Reuses the B2 service account (CUST_ACME_API_SVC) with key-pair auth.
-- Customer runs Snowflake-Labs/mcp locally or uses CoCo CLI.
-- MSP provides a locked-down MCP configuration YAML (Select only).
-- No additional SQL needed beyond the B2 block above.
----------------------------------------------------------------------

----------------------------------------------------------------------
-- VERIFICATION
----------------------------------------------------------------------

-- Confirm roles exist and have correct grants
SHOW GRANTS TO ROLE IDENTIFIER($cust_name || '_BI_READONLY');
SHOW GRANTS TO ROLE IDENTIFIER($cust_name || '_SI_READONLY');
SHOW GRANTS TO ROLE IDENTIFIER($cust_name || '_API_READONLY');
SHOW GRANTS TO ROLE IDENTIFIER($cust_name || '_MCP_READONLY');

-- Confirm service accounts have no password auth vector
SHOW USERS LIKE $cust_name || '_BI_SVC';
SHOW USERS LIKE $cust_name || '_API_SVC';
SHOW USERS LIKE $cust_name || '_MCP_USER';

-- Confirm human SI users have MFA, network policies, and CLIENT_TYPES applied
SHOW PARAMETERS LIKE 'NETWORK_POLICY'       IN USER IDENTIFIER($cust_name || '_SI_USER_1');
SHOW PARAMETERS LIKE 'AUTHENTICATION_POLICY' IN USER IDENTIFIER($cust_name || '_SI_USER_1');

-- Confirm MCP user has ONLY the MCP readonly role (OAuth secondary roles check)
SHOW GRANTS TO USER IDENTIFIER($cust_name || '_MCP_USER');

-- Confirm MCP server exists and has correct tools
DESCRIBE MCP SERVER IDENTIFIER($cust_name || '_MCP_SERVER');

-- Confirm no write privileges on any RAW or INTEGRATION objects
SELECT *
FROM   SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE  grantee_name IN (
    UPPER($cust_name) || '_BI_READONLY',
    UPPER($cust_name) || '_SI_READONLY',
    UPPER($cust_name) || '_API_READONLY',
    UPPER($cust_name) || '_MCP_READONLY'
)
   AND privilege NOT IN ('USAGE', 'SELECT')
ORDER BY grantee_name, granted_on, name;
