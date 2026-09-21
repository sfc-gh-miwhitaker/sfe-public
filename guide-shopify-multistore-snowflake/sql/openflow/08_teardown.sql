/*
  guide-shopify-multistore-snowflake — sql/openflow/08_teardown.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    Remove everything the Openflow path created, in dependency order. Each
    section is independent so you can, for example, drop only the analytics
    layer.

  IMPORTANT
    - Stop the connector process groups on the canvas FIRST, or the runtime
      may still be mid-MERGE when the tables disappear.
    - Dropping the deployment stops the Management Services compute pool and
      ends the always-on cost floor. Nothing else does.
    - Uninstall the Shopify dev app in each store's Dev Dashboard separately;
      Snowflake cannot revoke Shopify credentials.
    - The shared control database is NOT dropped here. It is path-independent
      and survives a migration to the native path. Drop it only when
      decommissioning Shopify ingestion entirely (section 6).

  RUN AS      OPENFLOW_ADMIN (sections 1-4), ACCOUNTADMIN (section 5+)

  -- Openflow DDL: syntax from docs, not executed.
*/

-- 1. Runtime and deployment (the always-on billing stops here) ----------------
USE ROLE OPENFLOW_ADMIN;

ALTER OPENFLOW RUNTIME IF EXISTS OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME SUSPEND;
DROP OPENFLOW RUNTIME IF EXISTS OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME;
DROP OPENFLOW DEPLOYMENT IF EXISTS SHOPIFY_DEPLOYMENT;

-- 2. Published contract surfaces ----------------------------------------------
--    Drop these before the analytics database so nothing downstream reads a
--    view over a missing table. Re-created by whichever path you deploy next.
DROP VIEW IF EXISTS SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY;
DROP VIEW IF EXISTS SHOPIFY_CONTROL.META.V_STORE_FRESHNESS;

-- 3. Analytics layer ----------------------------------------------------------
DROP DATABASE IF EXISTS SHOPIFY_ANALYTICS;
DROP WAREHOUSE IF EXISTS SHOPIFY_ANALYTICS_WH;

-- 4. Landed data and infrastructure -------------------------------------------
--    Irreversible past Time Travel; export first if you need the history.
DROP DATABASE IF EXISTS SHOPIFY_RAW;
DROP DATABASE IF EXISTS OPENFLOW_DB;
DROP WAREHOUSE IF EXISTS SHOPIFY_INGEST_WH;

-- 5. Account-level objects ----------------------------------------------------
USE ROLE ACCOUNTADMIN;
DROP INTEGRATION IF EXISTS OPENFLOW_SHOPIFY_RUNTIME_EAI;
DROP ROLE IF EXISTS SHOPIFY_ANALYST;
DROP ROLE IF EXISTS OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL;
-- Keep OPENFLOW_ADMIN if any other Openflow workload uses it.
-- DROP ROLE IF EXISTS OPENFLOW_ADMIN;

-- 6. Shared control plane (ONLY when retiring Shopify ingestion entirely) -----
--    Keep this if you are migrating to the native path: the registry, the
--    reconciliation baseline, and the contract definition are all reusable.
-- DROP DATABASE IF EXISTS SHOPIFY_CONTROL;
-- DROP ROLE IF EXISTS SHOPIFY_CONTROL_ADMIN;

-- 7. Verify nothing is still billing ------------------------------------------
SHOW OPENFLOW DEPLOYMENTS;
SHOW COMPUTE POOLS LIKE '%OPENFLOW%';
