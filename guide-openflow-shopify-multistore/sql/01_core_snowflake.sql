/*
  guide-openflow-shopify-multistore — 01_core_snowflake.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-03

  PURPOSE
    One-time account preparation for an Openflow Snowflake Deployment.
    Creates the OPENFLOW_ADMIN role, grants the account-level privileges the
    deployment requires, and creates the infrastructure database that will hold
    runtimes, connectors, network rules, and the event table.

  RUN AS      ACCOUNTADMIN (once)
  RUNTIME     < 1 minute
  SOURCE      https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-spcs-sf

  BEFORE YOU RUN
    Replace <OPENFLOW_USER> with the Snowflake login of the person who will
    administer Openflow and open the runtime canvas.
*/

USE ROLE ACCOUNTADMIN;

-- 1. Admin role ---------------------------------------------------------------
CREATE ROLE IF NOT EXISTS OPENFLOW_ADMIN
  COMMENT = 'Administers Openflow deployments, runtimes, and connectors';

GRANT ROLE OPENFLOW_ADMIN TO USER <OPENFLOW_USER>;

-- 2. Account-level privileges required for a Snowflake Deployment --------------
GRANT CREATE OPENFLOW DEPLOYMENT ON ACCOUNT TO ROLE OPENFLOW_ADMIN;
GRANT CREATE COMPUTE POOL        ON ACCOUNT TO ROLE OPENFLOW_ADMIN;  -- Snowflake deployments only
GRANT CREATE DATABASE            ON ACCOUNT TO ROLE OPENFLOW_ADMIN;
GRANT CREATE INTEGRATION         ON ACCOUNT TO ROLE OPENFLOW_ADMIN;  -- external access integrations

-- 3. Runtime login gotcha ------------------------------------------------------
--    Users whose DEFAULT_ROLE is ACCOUNTADMIN cannot log into a Snowflake
--    Deployment runtime canvas. Set a non-ACCOUNTADMIN default role and
--    secondary roles ALL for every person who will open the canvas.
ALTER USER <OPENFLOW_USER> SET DEFAULT_ROLE = OPENFLOW_ADMIN;
ALTER USER <OPENFLOW_USER> SET DEFAULT_SECONDARY_ROLES = ('ALL');

-- 4. Infrastructure database (keep separate from landed data) ------------------
USE ROLE OPENFLOW_ADMIN;

CREATE DATABASE IF NOT EXISTS OPENFLOW_DB
  COMMENT = 'Openflow infrastructure: runtimes, connectors, network rules, telemetry';

CREATE SCHEMA IF NOT EXISTS OPENFLOW_DB.OPENFLOW_SCHEMA
  COMMENT = 'Openflow runtime and connector objects';

-- 5. Schema-level privileges for runtime and connector objects -----------------
USE ROLE ACCOUNTADMIN;
GRANT CREATE OPENFLOW RUNTIME   ON SCHEMA OPENFLOW_DB.OPENFLOW_SCHEMA TO ROLE OPENFLOW_ADMIN;
GRANT CREATE OPENFLOW CONNECTOR ON SCHEMA OPENFLOW_DB.OPENFLOW_SCHEMA TO ROLE OPENFLOW_ADMIN;

-- 6. Dedicated event table for Openflow telemetry ------------------------------
--    Default is SNOWFLAKE.TELEMETRY.EVENTS; a dedicated table keeps Openflow
--    logs queryable without competing with other account telemetry.
USE ROLE OPENFLOW_ADMIN;
CREATE EVENT TABLE IF NOT EXISTS OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_EVENTS
  COMMENT = 'Openflow deployment and runtime logs/metrics';

-- 7. Verify -------------------------------------------------------------------
SHOW GRANTS TO ROLE OPENFLOW_ADMIN;
