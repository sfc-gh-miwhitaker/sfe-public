/*==============================================================================
  SINGLE USER PROVISIONING — guide-cowork-admin-setup
  Annotated walkthrough for provisioning one CoWork-only user.
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-07-22
==============================================================================*/

USE ROLE USERADMIN;  -- USERADMIN can create/alter users; ACCOUNTADMIN also works

-- ─── 1. Create the user ────────────────────────────────────────────────────
-- SSO/SAML accounts: omit PASSWORD entirely; set MUST_CHANGE_PASSWORD = FALSE
-- Password auth: add PASSWORD = 'TempPass1!' and MUST_CHANGE_PASSWORD = TRUE
CREATE USER IF NOT EXISTS alice
  LOGIN_NAME            = 'alice@yourcompany.com'   -- IdP login identifier
  DISPLAY_NAME          = 'Alice Smith'
  EMAIL                 = 'alice@yourcompany.com'
  DEFAULT_ROLE          = COWORK_USER
  DEFAULT_WAREHOUSE     = '<your_warehouse>'         -- required; CoWork tools run here
  MUST_CHANGE_PASSWORD  = FALSE;

-- ─── 2. Grant the CoWork role ──────────────────────────────────────────────
GRANT ROLE COWORK_USER TO USER alice;

-- ─── 3. Restrict interface to CoWork only ─────────────────────────────────
-- This blocks Snowsight. The user can only reach https://ai.snowflake.com.
-- ALLOWED_INTERFACES must be set via ALTER USER (not in CREATE USER).
ALTER USER alice SET ALLOWED_INTERFACES = (SNOWFLAKE_INTELLIGENCE);

-- ─── 4. Verify ────────────────────────────────────────────────────────────
DESCRIBE USER alice;
-- Check: DEFAULT_ROLE = COWORK_USER, ALLOWED_INTERFACES = SNOWFLAKE_INTELLIGENCE

SHOW GRANTS TO USER alice;
-- Check: COWORK_USER appears
