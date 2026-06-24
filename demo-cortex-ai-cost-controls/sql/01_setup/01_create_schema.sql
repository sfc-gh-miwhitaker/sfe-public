/*==============================================================================
01_SETUP — Schema, warehouse context, and access grant
Cortex AI Cost Controls demo | Expires: 2026-07-24
Run by: ACCOUNTADMIN (needed for IMPORTED PRIVILEGES grant), then SYSADMIN owns
        the objects. Invoked from deploy_all.sql via EXECUTE IMMEDIATE FROM.
==============================================================================*/

-- The schema and warehouse are created in deploy_all.sql's shared-infra block.
-- This script confirms context and ensures the running role can read the
-- Cortex usage views in SNOWFLAKE.ACCOUNT_USAGE.

USE ROLE SYSADMIN;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS
  COMMENT = 'DEMO: Cortex AI cost monitoring & controls dashboard (Expires: 2026-07-24)';

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS;
USE WAREHOUSE SFE_CORTEX_AI_COST_CONTROLS_WH;

-- ACCOUNT_USAGE Cortex views require IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE.
-- ACCOUNTADMIN holds this implicitly; grant it to SYSADMIN so the dashboard's
-- query warehouse (running as SYSADMIN) can read the views. Idempotent.
USE ROLE ACCOUNTADMIN;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE SYSADMIN;
USE ROLE SYSADMIN;

SELECT 'Schema and grants ready' AS step_01_setup;
