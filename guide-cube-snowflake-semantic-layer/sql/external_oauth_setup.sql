/*
  Cube on Snowflake — External OAuth (OIDC workload identity) setup
  Pair-programmed by SE Community + Cortex Code

  Configures Snowflake to trust Cube Cloud's OIDC issuer so the Cube Snowflake
  driver authenticates with a short-lived, Cube-minted JWT. No long-lived secret
  is provisioned in Snowflake and no key material changes hands.

  Every statement here was executed against a live Snowflake account and verified.

  PREREQUISITES
    - Run as ACCOUNTADMIN (CREATE INTEGRATION and CREATE USER are account-level).
    - In Cube Cloud, create the OIDC token config FIRST (Admin -> OIDC -> Add Config):
        Audience Type    : Custom
        Custom Audience  : https://<account-identifier>.snowflakecomputing.com
        Custom Claims    : scp = session:role-any
        Target Env Var   : CUBEJS_DB_SNOWFLAKE_OAUTH_TOKEN_PATH
      Note the rendered "sub" value from the dialog's live preview — you need it
      for LOGIN_NAME in step 3.

  REPLACE BEFORE RUNNING
    <tenant-name>        Your Cube Cloud tenant name
    <account-identifier> Your Snowflake account identifier
    <deployment-id>      Cube deployment ID (the number in your deployment console URL)
    ANALYTICS            Your database
    CUBE_WH              Your warehouse
*/

-- =============================================================================
-- 1. Warehouse and role
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS CUBE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  -- Bound runaway pre-aggregation rebuilds. Tune to your largest expected rollup.
  STATEMENT_TIMEOUT_IN_SECONDS = 3600
  COMMENT = 'Compute for the Cube semantic layer';

CREATE ROLE IF NOT EXISTS CUBE_ROLE
  COMMENT = 'Read-only role used by the Cube semantic layer';

-- =============================================================================
-- 2. External OAuth security integration
--
-- The issuer and audience must match the Cube token config EXACTLY — these values
-- are case-sensitive. A mismatch surfaces as a generic "Invalid OAuth access token".
--
-- EXTERNAL_OAUTH_ANY_ROLE_MODE = 'ENABLE' lets the driver request any role granted
-- to the mapped user, paired with scp = session:role-any in the token.
-- To pin the role inside the token instead, use scp = session:role:CUBE_ROLE and
-- set this to 'DISABLE'.
-- =============================================================================

CREATE OR REPLACE SECURITY INTEGRATION CUBE_CLOUD_EXTERNAL_OAUTH
  TYPE = EXTERNAL_OAUTH
  ENABLED = TRUE
  EXTERNAL_OAUTH_TYPE = CUSTOM
  EXTERNAL_OAUTH_ISSUER = 'https://<tenant-name>.cubecloud.dev'
  EXTERNAL_OAUTH_JWS_KEYS_URL = 'https://<tenant-name>.cubecloud.dev/.well-known/jwks.json'
  EXTERNAL_OAUTH_AUDIENCE_LIST = ('https://<account-identifier>.snowflakecomputing.com')
  EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = 'sub'
  EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'LOGIN_NAME'
  EXTERNAL_OAUTH_ANY_ROLE_MODE = 'ENABLE'
  COMMENT = 'Trusts Cube Cloud OIDC issuer for workload identity federation';

-- Optional but recommended: restrict which source addresses may present a token.
-- Snowflake's custom-authorization-server user guide claims network policies cannot
-- be attached to External OAuth integrations. That statement is stale — this works,
-- and the setting persists in DESC SECURITY INTEGRATION output (verified).
-- Populate ALLOWED_IP_LIST with your Cube Cloud deployment's egress address, shown
-- in Cube Cloud under Settings -> Configuration.
/*
CREATE NETWORK POLICY IF NOT EXISTS CUBE_ALLOWED_IPS
  ALLOWED_IP_LIST = ('203.0.113.0/24')
  COMMENT = 'Egress addresses for the Cube Cloud deployment';

ALTER SECURITY INTEGRATION CUBE_CLOUD_EXTERNAL_OAUTH
  SET NETWORK_POLICY = 'CUBE_ALLOWED_IPS';
*/

-- =============================================================================
-- 3. Service user
--
-- LOGIN_NAME must equal the token's rendered "sub" claim. With Cube's default
-- subject claim format that is cube:deployment:<deployment-id>. If you chose a
-- different template, copy the exact value from the token-config live preview.
--
-- TYPE = SERVICE is enforced, not advisory. Verified behavior:
--   ALTER USER ... SET PASSWORD -> 511503 (23001): SQL execution error:
--   Cannot set PASSWORD on users with TYPE=SERVICE.
-- The user can only authenticate through the federation.
-- =============================================================================

CREATE USER IF NOT EXISTS CUBE_SVC
  TYPE = SERVICE
  LOGIN_NAME = 'cube:deployment:<deployment-id>'
  DEFAULT_ROLE = CUBE_ROLE
  DEFAULT_WAREHOUSE = CUBE_WH
  COMMENT = 'Service identity for the Cube semantic layer (OIDC federated)';

GRANT ROLE CUBE_ROLE TO USER CUBE_SVC;

-- =============================================================================
-- 4. Read-only data access
--
-- This is all Cube needs to serve queries. Write access is required ONLY for
-- pre-aggregations built with the default batching strategy (section 5).
-- =============================================================================

GRANT USAGE ON WAREHOUSE CUBE_WH TO ROLE CUBE_ROLE;

GRANT USAGE  ON DATABASE ANALYTICS                  TO ROLE CUBE_ROLE;
GRANT USAGE  ON ALL SCHEMAS    IN DATABASE ANALYTICS TO ROLE CUBE_ROLE;
GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE ANALYTICS TO ROLE CUBE_ROLE;
GRANT SELECT ON ALL TABLES     IN DATABASE ANALYTICS TO ROLE CUBE_ROLE;
GRANT SELECT ON FUTURE TABLES  IN DATABASE ANALYTICS TO ROLE CUBE_ROLE;
GRANT SELECT ON ALL VIEWS      IN DATABASE ANALYTICS TO ROLE CUBE_ROLE;
GRANT SELECT ON FUTURE VIEWS   IN DATABASE ANALYTICS TO ROLE CUBE_ROLE;

-- =============================================================================
-- 5. OPTIONAL — write access for batching-strategy pre-aggregations
--
-- Skip this entirely if you use the export bucket strategy, which unloads via
-- COPY INTO and needs only USAGE on the storage integration.
-- =============================================================================

/*
CREATE SCHEMA IF NOT EXISTS ANALYTICS.CUBE_PRE_AGGREGATIONS
  COMMENT = 'Target for Cube pre-aggregation rollups (batching strategy)';

GRANT USAGE, CREATE TABLE, CREATE VIEW
  ON SCHEMA ANALYTICS.CUBE_PRE_AGGREGATIONS TO ROLE CUBE_ROLE;
*/

-- =============================================================================
-- 6. OPTIONAL — privileges for pushing Cube views as Snowflake semantic views
--
-- Requires Cube Enterprise plan and "Enable DDL operations" in the Cube Cloud
-- deployment configuration (Deployment Settings -> Configuration).
--
-- CREATE VIEW is needed only if a cube uses a plain SQL string in its `sql`
-- property; Cube then creates a CUBE_SV_SRC_<CUBENAME> helper view as the
-- semantic view's source. Prefer sql_table for straightforward table access
-- to avoid helper views entirely.
--
-- Both grants verified as valid at schema level.
-- =============================================================================

/*
CREATE SCHEMA IF NOT EXISTS ANALYTICS.CUBE_SV
  COMMENT = 'Target for semantic views pushed from Cube';

GRANT USAGE               ON SCHEMA ANALYTICS.CUBE_SV TO ROLE CUBE_ROLE;
GRANT CREATE SEMANTIC VIEW ON SCHEMA ANALYTICS.CUBE_SV TO ROLE CUBE_ROLE;
GRANT CREATE VIEW          ON SCHEMA ANALYTICS.CUBE_SV TO ROLE CUBE_ROLE;
*/

-- =============================================================================
-- 7. Verify
-- =============================================================================

-- Confirm every integration parameter landed as intended.
DESC SECURITY INTEGRATION CUBE_CLOUD_EXTERNAL_OAUTH;

-- Confirm the service user's type and login name.
SHOW USERS LIKE 'CUBE_SVC';

-- Confirm the role's grants.
SHOW GRANTS TO ROLE CUBE_ROLE;

/*
  NEXT: configure the Cube deployment. Set the OAUTH authenticator and omit
  CUBEJS_DB_USER / CUBEJS_DB_PASS entirely.

    CUBEJS_DB_TYPE=snowflake
    CUBEJS_DB_SNOWFLAKE_ACCOUNT=<account-identifier>
    CUBEJS_DB_SNOWFLAKE_WAREHOUSE=CUBE_WH
    CUBEJS_DB_NAME=ANALYTICS
    CUBEJS_DB_SNOWFLAKE_ROLE=CUBE_ROLE
    CUBEJS_DB_SNOWFLAKE_AUTHENTICATOR=OAUTH

  Do NOT set CUBEJS_DB_SNOWFLAKE_OAUTH_TOKEN_PATH by hand — Cube populates it from
  the token config's Target Env Var, and the path differs across execution contexts
  (deployed pods, dev mode, test connection). The driver re-reads the file on every
  new connection, so token refresh is picked up without a restart.

  Then run any query from Cube and confirm the federation in login history — see
  observability.sql, query 1. Expect FIRST_AUTHENTICATION_FACTOR = OAUTH_ACCESS_TOKEN.
*/
