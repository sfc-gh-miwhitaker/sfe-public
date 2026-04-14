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
SET api_server_ip      = '0.0.0.0/32';          -- Option B2: customer app server IP

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
-- VERIFICATION
----------------------------------------------------------------------

-- Confirm roles exist and have correct grants
SHOW GRANTS TO ROLE IDENTIFIER($cust_name || '_BI_READONLY');
SHOW GRANTS TO ROLE IDENTIFIER($cust_name || '_SI_READONLY');
SHOW GRANTS TO ROLE IDENTIFIER($cust_name || '_API_READONLY');

-- Confirm service accounts have no password auth vector
SHOW USERS LIKE $cust_name || '_BI_SVC';
SHOW USERS LIKE $cust_name || '_API_SVC';

-- Confirm human SI users have MFA, network policies, and CLIENT_TYPES applied
SHOW PARAMETERS LIKE 'NETWORK_POLICY'       IN USER IDENTIFIER($cust_name || '_SI_USER_1');
SHOW PARAMETERS LIKE 'AUTHENTICATION_POLICY' IN USER IDENTIFIER($cust_name || '_SI_USER_1');

-- Confirm no write privileges on any RAW or INTEGRATION objects
SELECT *
FROM   SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE  grantee_name IN (
    UPPER($cust_name) || '_BI_READONLY',
    UPPER($cust_name) || '_SI_READONLY',
    UPPER($cust_name) || '_API_READONLY'
)
   AND privilege NOT IN ('USAGE', 'SELECT')
ORDER BY grantee_name, granted_on, name;
