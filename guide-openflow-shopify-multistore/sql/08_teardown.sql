/*
  guide-openflow-shopify-multistore — 08_teardown.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-03

  PURPOSE
    Remove everything this guide created, in dependency order. Each section is
    independent so you can, for example, drop only the analytics layer.

  IMPORTANT
    - Stop the connector process groups on the canvas FIRST, or the runtime
      may still be mid-MERGE when the tables disappear.
    - Dropping the deployment stops the Management Services compute pool and
      ends the always-on cost floor. Nothing else does.
    - Uninstall the Shopify dev app in each store's Dev Dashboard separately;
      Snowflake cannot revoke Shopify credentials.

  RUN AS      OPENFLOW_ADMIN (sections 1-4), ACCOUNTADMIN (section 5)

  -- Openflow DDL: syntax from docs, not executed.
*/

-- 1. Runtime and deployment (billing stops here) --------------------------------
USE ROLE OPENFLOW_ADMIN;

ALTER OPENFLOW RUNTIME IF EXISTS OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME SUSPEND;
DROP OPENFLOW RUNTIME IF EXISTS OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME;
DROP OPENFLOW DEPLOYMENT IF EXISTS SHOPIFY_DEPLOYMENT;

-- 2. Analytics layer -----------------------------------------------------------
DROP DATABASE IF EXISTS SHOPIFY_ANALYTICS;
DROP WAREHOUSE IF EXISTS SHOPIFY_ANALYTICS_WH;

-- 3. Landed data (irreversible past Time Travel; export first if needed) ---------
DROP DATABASE IF EXISTS SHOPIFY_RAW;

-- 4. Infrastructure database (network rule, event table) ------------------------
DROP DATABASE IF EXISTS OPENFLOW_DB;
DROP WAREHOUSE IF EXISTS SHOPIFY_INGEST_WH;

-- 5. Account-level objects -----------------------------------------------------
USE ROLE ACCOUNTADMIN;
DROP INTEGRATION IF EXISTS OPENFLOW_SHOPIFY_RUNTIME_EAI;
DROP ROLE IF EXISTS SHOPIFY_ANALYST;
DROP ROLE IF EXISTS OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL;
-- Keep OPENFLOW_ADMIN if any other Openflow workload uses it.
-- DROP ROLE IF EXISTS OPENFLOW_ADMIN;

-- 6. Verify nothing is still billing -----------------------------------------
SHOW OPENFLOW DEPLOYMENTS;
SHOW COMPUTE POOLS LIKE '%OPENFLOW%';
