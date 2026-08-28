/*==============================================================================
OPENFLOW ADS CONNECTORS — SNOWFLAKE PREREQUISITE SETUP
Pair-programmed by SE Community + Cortex Code | Expires: 2026-11-28

WHAT THIS IS
  The Snowflake-side prerequisites for the Openflow Connector for Meta Ads and
  the Openflow Connector for Google Ads: the admin role and account privileges,
  outbound network access, and the destination objects the connectors write to.

  It is NOT the full setup. Creating the deployment, the execute-as role, the
  runtime, and configuring the connector itself all happen in the Openflow UI,
  not in SQL. See the docs links at the bottom for those steps.

PROVENANCE
  Sections 1-3 were EXECUTED against a live Snowflake account (v10.30.102) on
  2026-08-28 and then dropped:
    - all three Openflow account privileges granted to a non-ACCOUNTADMIN role
      and confirmed present in SHOW GRANTS
    - both EGRESS network rules and both external access integrations created
  Section 4 destination DDL is transcribed from Snowflake's connector setup docs.

  NOT executed: the deployment, runtime, and connector flow. The validation
  account had no Openflow deployment (SHOW OPENFLOW DATA PLANE INTEGRATIONS
  returned no rows).

STATUS
  Openflow - Snowflake Deployments: Generally Available (AWS, Azure, GCP
    commercial regions), runs on Snowpark Container Services.
  Openflow - BYOC: Generally Available, AWS commercial regions only.
  The Meta Ads and Google Ads CONNECTORS: Preview, subject to the Snowflake
    Connector Terms.

PREREQUISITES
  ACCOUNTADMIN, which holds the three Openflow account privileges by default.
  Openflow - Snowflake Deployment is not automatically available in trial
  accounts; request it through your account team.
==============================================================================*/


/*==============================================================================
SECTION 1 — OPENFLOW ADMIN ROLE

  Two documented behaviors that catch people, both the OPPOSITE of what a
  connector service identity wants:

  1. A user whose DEFAULT_ROLE is ACCOUNTADMIN CANNOT log in to an Openflow
     runtime. They get an error. Assign a different default role to anyone who
     needs runtime access.

  2. Snowflake RECOMMENDS DEFAULT_SECONDARY_ROLES = ('ALL') for Openflow users.
     Note this is the reverse of the hardening applied to the Google Ads Data
     Manager service user in google_ads_data_manager_setup.sql, which sets
     DEFAULT_SECONDARY_ROLES = (). Both are correct for their context: that one
     is a machine identity scoped to a single PII view; this is a human who has
     to reach many objects across the setup flow.
==============================================================================*/
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS OPENFLOW_ADMIN
    COMMENT = 'Openflow deployment and runtime administration (Expires: 2026-11-28)';

GRANT ROLE OPENFLOW_ADMIN TO USER <openflow_user>;

ALTER USER <openflow_user> SET DEFAULT_ROLE = OPENFLOW_ADMIN;
ALTER USER <openflow_user> SET DEFAULT_SECONDARY_ROLES = ('ALL');


/*==============================================================================
SECTION 2 — ACCOUNT PRIVILEGES

  Exactly three. VERIFIED BY EXECUTION: all three grant successfully to a
  non-ACCOUNTADMIN role and appear in SHOW GRANTS TO ROLE afterward.

  CREATE COMPUTE POOL is documented on the "Core Snowflake" setup page rather
  than the deployment page. A deployment is backed by a compute pool and cannot
  be created without it, so confirm this grant explicitly rather than assuming
  it came along with the other two.
==============================================================================*/
GRANT CREATE OPENFLOW DATA PLANE INTEGRATION ON ACCOUNT TO ROLE OPENFLOW_ADMIN;
GRANT CREATE OPENFLOW RUNTIME INTEGRATION    ON ACCOUNT TO ROLE OPENFLOW_ADMIN;
GRANT CREATE COMPUTE POOL                    ON ACCOUNT TO ROLE OPENFLOW_ADMIN;

-- Confirm all three landed before moving on.
SHOW GRANTS TO ROLE OPENFLOW_ADMIN;


/*==============================================================================
SECTION 3 — OUTBOUND NETWORK ACCESS

  Openflow runtimes have NO outbound access by default. Each connector needs a
  network rule naming its endpoint, wrapped in an external access integration
  that gets attached to the runtime's execute-as role.

  Endpoints:
    Meta Ads   -> graph.facebook.com
    Google Ads -> googleads.googleapis.com

  Separate rules per connector keep each EAI scoped to a single endpoint. One
  combined rule also works; the tradeoff is that any runtime granted that EAI
  can reach both providers.

  VERIFIED BY EXECUTION: both rules and both integrations create successfully,
  and SHOW NETWORK RULES reports MODE = EGRESS, TYPE = HOST_PORT.
==============================================================================*/
CREATE DATABASE IF NOT EXISTS OPENFLOW_CONFIG
    COMMENT = 'Openflow network rules and supporting objects (Expires: 2026-11-28)';

CREATE SCHEMA IF NOT EXISTS OPENFLOW_CONFIG.NETWORKING
    COMMENT = 'Egress rules for Openflow connectors (Expires: 2026-11-28)';

CREATE OR REPLACE NETWORK RULE OPENFLOW_CONFIG.NETWORKING.META_ADS_EGRESS
    MODE       = EGRESS
    TYPE       = HOST_PORT
    VALUE_LIST = ('graph.facebook.com')
    COMMENT    = 'Meta Ads Insights API endpoint (Expires: 2026-11-28)';

CREATE OR REPLACE NETWORK RULE OPENFLOW_CONFIG.NETWORKING.GOOGLE_ADS_EGRESS
    MODE       = EGRESS
    TYPE       = HOST_PORT
    VALUE_LIST = ('googleads.googleapis.com')
    COMMENT    = 'Google Ads API endpoint (Expires: 2026-11-28)';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION META_ADS_EAI
    ALLOWED_NETWORK_RULES = (OPENFLOW_CONFIG.NETWORKING.META_ADS_EGRESS)
    ENABLED = TRUE
    COMMENT = 'Openflow Meta Ads connector egress (Expires: 2026-11-28)';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION GOOGLE_ADS_EAI
    ALLOWED_NETWORK_RULES = (OPENFLOW_CONFIG.NETWORKING.GOOGLE_ADS_EGRESS)
    ENABLED = TRUE
    COMMENT = 'Openflow Google Ads connector egress (Expires: 2026-11-28)';

SHOW NETWORK RULES IN SCHEMA OPENFLOW_CONFIG.NETWORKING;

-- The execute-as role you create in the Openflow UI needs USAGE on the EAI it
-- will use. Substitute the actual execute-as role name.
-- GRANT USAGE ON INTEGRATION META_ADS_EAI   TO ROLE <execute_as_role>;
-- GRANT USAGE ON INTEGRATION GOOGLE_ADS_EAI TO ROLE <execute_as_role>;


/*==============================================================================
SECTION 4 — DESTINATION OBJECTS

  The database and schema must EXIST BEFORE the connector is installed. The
  connector creates the destination tables itself, which is why it needs
  CREATE TABLE rather than ownership.

  Destination names are CASE-SENSITIVE in the connector parameters. For
  unquoted identifiers, supply the name in uppercase:
    CREATE SCHEMA schema_name    -> enter SCHEMA_NAME
    CREATE SCHEMA "schema_name"  -> enter schema_name

  Substitute <connector_role> with the execute-as role for the runtime hosting
  the connector.
==============================================================================*/

-- Meta Ads
CREATE DATABASE IF NOT EXISTS META_ADS_DESTINATION_DB
    COMMENT = 'Openflow Meta Ads landing (Expires: 2026-11-28)';
CREATE SCHEMA IF NOT EXISTS META_ADS_DESTINATION_DB.META_ADS_DESTINATION_SCHEMA
    COMMENT = 'Openflow Meta Ads report tables (Expires: 2026-11-28)';

GRANT USAGE        ON DATABASE META_ADS_DESTINATION_DB
    TO ROLE <connector_role>;
GRANT USAGE        ON SCHEMA   META_ADS_DESTINATION_DB.META_ADS_DESTINATION_SCHEMA
    TO ROLE <connector_role>;
GRANT CREATE TABLE ON SCHEMA   META_ADS_DESTINATION_DB.META_ADS_DESTINATION_SCHEMA
    TO ROLE <connector_role>;

-- Google Ads
CREATE DATABASE IF NOT EXISTS GOOGLE_ADS_DESTINATION_DB
    COMMENT = 'Openflow Google Ads landing (Expires: 2026-11-28)';
CREATE SCHEMA IF NOT EXISTS GOOGLE_ADS_DESTINATION_DB.GOOGLE_ADS_DESTINATION_SCHEMA
    COMMENT = 'Openflow Google Ads report tables (Expires: 2026-11-28)';

GRANT USAGE        ON DATABASE GOOGLE_ADS_DESTINATION_DB
    TO ROLE <connector_role>;
GRANT USAGE        ON SCHEMA   GOOGLE_ADS_DESTINATION_DB.GOOGLE_ADS_DESTINATION_SCHEMA
    TO ROLE <connector_role>;
GRANT CREATE TABLE ON SCHEMA   GOOGLE_ADS_DESTINATION_DB.GOOGLE_ADS_DESTINATION_SCHEMA
    TO ROLE <connector_role>;


/*==============================================================================
SECTION 5 — OPTIONAL: DEDICATED EVENT TABLE

  Openflow sends logs and metrics to the account event table
  (SNOWFLAKE.TELEMETRY.EVENTS) by default. Snowflake recommends a dedicated
  per-deployment event table for query performance, granular access control,
  and simpler monitoring.
==============================================================================*/
-- USE ROLE ACCOUNTADMIN;
-- GRANT USAGE ON DATABASE OPENFLOW_CONFIG            TO ROLE OPENFLOW_ADMIN;
-- GRANT USAGE ON SCHEMA   OPENFLOW_CONFIG.NETWORKING TO ROLE OPENFLOW_ADMIN;
--
-- USE ROLE OPENFLOW_ADMIN;
-- CREATE EVENT TABLE IF NOT EXISTS OPENFLOW_CONFIG.NETWORKING.EVENTS;
--
-- -- Get the data plane name from the "name" column:
-- SHOW OPENFLOW DATA PLANE INTEGRATIONS;
--
-- ALTER OPENFLOW DATA PLANE INTEGRATION <dataplane_integration_name>
--     SET EVENT_TABLE = 'OPENFLOW_CONFIG.NETWORKING.EVENTS';


/*==============================================================================
SECTION 6 — OPTIONAL: MONITORING ROLE

  Lets operations staff monitor deployments and runtimes without holding
  OPENFLOW_ADMIN.
==============================================================================*/
-- USE ROLE OPENFLOW_ADMIN;
-- CREATE ROLE IF NOT EXISTS OPENFLOW_MONITOR;
-- GRANT MONITOR ON INTEGRATION <dataplane_integration_name> TO ROLE OPENFLOW_MONITOR;
-- GRANT ROLE OPENFLOW_MONITOR TO ROLE OPENFLOW_ADMIN;
-- GRANT ROLE OPENFLOW_MONITOR TO USER <snowflake_user>;


/*==============================================================================
SECTION 7 — WHAT HAPPENS OUTSIDE SQL

  The remaining steps are UI work in Snowsight under Ingestion » Openflow:

  1. Create a deployment. Select Snowflake as the deployment location, name it.
     No separate charge for the deployment itself; only active runtimes consume
     credits. Enable the PrivateLink option at creation time if you need
     PrivateLink UI access later (Business Critical Edition only).

  2. Create an execute-as role and attach the external access integrations from
     Section 3. On Snowflake Deployments, execute-as roles are linked to
     Openflow session tokens, which removes the need for a separate service
     user and key pair.

  3. Create a runtime associated with that execute-as role.

  4. Install the connector: Openflow overview » View more connectors » find the
     connector » Install » choose runtime.

  5. Configure flow parameters, then right-click the process group and Start.

  Steps 1-3 are typically repeated per connector.

  CREDENTIALS NEEDED FROM THE AD PLATFORM SIDE:
    Meta Ads   - a Meta App with Marketing API enabled, plus a long-lived token.
                 For higher rate limits, change the app from Standard to
                 Advanced access on Ads Management Standard Access and enable
                 ads_read and ads_management.
    Google Ads - a Google Cloud project with the Google Ads API enabled,
                 service account authentication, and a developer token at
                 Basic or Standard access level.

  AUTHENTICATION STRATEGY PARAMETER:
    SNOWFLAKE_MANAGED - Snowflake Deployments, or BYOC with runtime roles
                        configured. Account identifier, username, and private
                        key fields must all be BLANK.
    KEY_PAIR          - BYOC only. Needs a TYPE = SERVICE user, a PKCS8 RSA
                        private key with standard PEM headers, and the account
                        identifier as [org-name]-[account-name].

  Where key-pair auth is used, Snowflake recommends storing the keys in a
  supported secrets manager (AWS, Azure, HashiCorp) and referencing them via an
  Openflow Parameter Provider, so no sensitive values persist in Openflow.
==============================================================================*/


/*==============================================================================
SECTION 8 — DOCUMENTED LIMITATIONS TO DESIGN AROUND

  Meta Ads connector:
    - Incremental ingestion is supported ONLY when Report Time Increment is
      daily. Every other increment is snapshot-only.
    - Changing a report definition while processors are running can produce
      data inconsistencies. Stop processors and clear queues first.
    - If the Meta Ads API rate limit is reached, data does NOT get ingested
      while the connector keeps attempting to pull. Failure is quiet.
    - Data can be fetched only from the past 37 months (Meta-imposed).
    - Report Name becomes the destination table name and must be unique in the
      schema, so one report definition maps to one table.

  Google Ads connector:
    - Two modes: snapshot (default, appends each run) and incremental (enabled
      by including the segments.date segment). Incremental overlaps by the
      conversion window, so a 14-day window on a daily run repeats 13 days of
      data. Plan deduplication.
    - No filtering, no custom columns, no attributed-resource ingestion.
    - One report per (resource name, client ID) pair.
    - All-zero metric rows are dropped when segmenting.

  On the Meta Marketing API version: the connector setup documentation lists
  v22.0 as the allowed value for the Meta Ads Version parameter. Meta retires
  Marketing API versions on its own schedule. Confirm the version the connector
  currently supports with Snowflake before committing to a long-lived design
  that depends on it.

  RESETTING A CONNECTOR:
    1. Drain the queues so no flow files remain.
    2. Stop all processors.
    3. Right-click the initial processor and select View State, then Clear State.
       Meta Ads:   "Create Meta Ads Report"
       Google Ads: "Get Google Ads Report"
    4. Drop the destination table.
==============================================================================*/


/*==============================================================================
SECTION 9 — TEARDOWN

  Removes only what this file creates. Drop the Openflow deployment and runtimes
  from the Openflow UI first, since the EAIs are attached to execute-as roles.
==============================================================================*/
-- USE ROLE ACCOUNTADMIN;
--
-- DROP EXTERNAL ACCESS INTEGRATION IF EXISTS META_ADS_EAI;
-- DROP EXTERNAL ACCESS INTEGRATION IF EXISTS GOOGLE_ADS_EAI;
-- DROP DATABASE IF EXISTS OPENFLOW_CONFIG;
--
-- -- Destination data. Confirm it is no longer needed; these hold ingested rows.
-- DROP DATABASE IF EXISTS META_ADS_DESTINATION_DB;
-- DROP DATABASE IF EXISTS GOOGLE_ADS_DESTINATION_DB;
--
-- REVOKE CREATE OPENFLOW DATA PLANE INTEGRATION ON ACCOUNT FROM ROLE OPENFLOW_ADMIN;
-- REVOKE CREATE OPENFLOW RUNTIME INTEGRATION    ON ACCOUNT FROM ROLE OPENFLOW_ADMIN;
-- REVOKE CREATE COMPUTE POOL                    ON ACCOUNT FROM ROLE OPENFLOW_ADMIN;
-- DROP ROLE IF EXISTS OPENFLOW_MONITOR;
-- DROP ROLE IF EXISTS OPENFLOW_ADMIN;


/*==============================================================================
REFERENCES
  Core Snowflake setup (the three privileges above)
    https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-spcs-sf
  Task overview
    https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-spcs
  Create deployment
    https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-spcs-deployment
  Meta Ads connector - about / setup
    https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/meta-ads/about
    https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/meta-ads/setup
  Google Ads connector - about / setup
    https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/google-ads/about
    https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/google-ads/setup
==============================================================================*/
