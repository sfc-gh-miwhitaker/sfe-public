/*
  guide-shopify-multistore-snowflake — sql/native/07_teardown.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    Remove everything the native path created, in dependency order.

  IMPORTANT
    - Suspend the task first so nothing is mid-COPY when tables disappear.
    - Dropping SHOPIFY_NATIVE destroys the raw stage and every landed JSONL
      file. That is irreversible past Time Travel; export first if you need it.
    - Uninstall the Shopify dev app in each store's Dev Dashboard separately;
      Snowflake cannot revoke Shopify credentials.
    - The shared control database is NOT dropped here. It is path-independent
      and survives a migration to the Openflow path.

  RUN AS      SHOPIFY_PIPELINE_RL, then ACCOUNTADMIN
*/

USE ROLE SHOPIFY_PIPELINE_RL;
ALTER TASK IF EXISTS SHOPIFY_NATIVE.CONTROL.DAILY_SHOPIFY_PULL SUSPEND;
DROP TASK IF EXISTS SHOPIFY_NATIVE.CONTROL.DAILY_SHOPIFY_PULL;

-- Published contract surfaces first, so nothing reads a view over a missing table.
DROP VIEW IF EXISTS SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY;
DROP VIEW IF EXISTS SHOPIFY_CONTROL.META.V_STORE_FRESHNESS;

USE ROLE ACCOUNTADMIN;
DROP INTEGRATION IF EXISTS SHOPIFY_NATIVE_EAI;

-- Drop store secrets explicitly, after confirming no other object references them.
-- DROP SECRET IF EXISTS SHOPIFY_NATIVE.CONTROL.SHOPIFY_STORE_ALPHA_CREDENTIALS;

DROP DATABASE IF EXISTS SHOPIFY_NATIVE;
DROP WAREHOUSE IF EXISTS SHOPIFY_PIPELINE_WH;
DROP ROLE IF EXISTS SHOPIFY_ANALYST;
DROP ROLE IF EXISTS SHOPIFY_PIPELINE_RL;

-- Shared control plane: ONLY when retiring Shopify ingestion entirely.
-- Keep it if you are migrating to the Openflow path.
-- DROP DATABASE IF EXISTS SHOPIFY_CONTROL;
-- DROP ROLE IF EXISTS SHOPIFY_CONTROL_ADMIN;
