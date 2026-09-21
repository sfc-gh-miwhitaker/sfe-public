/*
  guide-shopify-multistore-snowflake — sql/openflow/05_store_schemas.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    The Openflow landing zone. One database (SHOPIFY_RAW), one schema per store,
    all created from the SHARED registry so adding store #23 is one CALL, not a
    hand-edited script.

  WHY ONE SCHEMA PER STORE
    The connector creates tables named ORDERS, ORDER_LINE_ITEMS, ... in whatever
    Destination Schema you give it. Snowflake docs confirm the merge key is
    (ID, SHOP_URL), which suggests a shared table could work, but no
    documentation states that multiple connector instances writing the same
    table is supported. One schema per store is the path with no undocumented
    behaviour: the blast radius is one store, a state reset drops one store's
    tables, and the analytics layer UNION ALLs across schemas (06).

    This is the structural difference from the native path, which lands every
    store in one STORE_KEY-partitioned raw table. Same contract out, different
    SQL to get there.

  PREREQUISITE
    sql/shared/01_store_registry.sql and sql/openflow/03_execute_as_role_eai.sql

  RUN AS      OPENFLOW_ADMIN (owns SHOPIFY_RAW)
  RUNTIME     < 1 minute
*/

USE ROLE OPENFLOW_ADMIN;

CREATE DATABASE IF NOT EXISTS SHOPIFY_RAW
  COMMENT = 'Raw Shopify data landed by Openflow; one schema per store';

GRANT USAGE ON DATABASE SHOPIFY_RAW TO ROLE OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL;

-- 1. Create the landing schema for one registered store ------------------------
--    The store must already exist in SHOPIFY_CONTROL.META.STORE_REGISTRY.
--    Registration and landing-schema creation are separate on purpose: the
--    registry is shared between both paths, the schema layout is not.
CREATE OR REPLACE PROCEDURE SHOPIFY_RAW.PUBLIC.CREATE_STORE_SCHEMA(P_STORE_KEY VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Creates SHOPIFY_RAW.<STORE_KEY> and grants the execute-as role. Idempotent. Requires the store to be registered.'
EXECUTE AS CALLER
AS
$$
DECLARE
  V_KEY      VARCHAR;
  V_SCHEMA   VARCHAR;
  V_DOMAIN   VARCHAR;
  V_REGISTERED NUMBER;
BEGIN
  V_KEY := UPPER(:P_STORE_KEY);

  SELECT COUNT(*), MAX(SHOP_DOMAIN)
    INTO :V_REGISTERED, :V_DOMAIN
  FROM SHOPIFY_CONTROL.META.STORE_REGISTRY
  WHERE STORE_KEY = :V_KEY;

  IF (:V_REGISTERED = 0) THEN
    RETURN 'ERROR: ' || :V_KEY || ' is not in STORE_REGISTRY. '
        || 'Fix: CALL SHOPIFY_CONTROL.META.ADD_STORE(...) first.';
  END IF;

  V_SCHEMA := 'SHOPIFY_RAW.' || :V_KEY;

  EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS ' || :V_SCHEMA
    || ' COMMENT = ''Openflow Shopify landing for ' || :V_DOMAIN || '''';
  EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA ' || :V_SCHEMA
    || ' TO ROLE OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL';
  EXECUTE IMMEDIATE 'GRANT CREATE TABLE ON SCHEMA ' || :V_SCHEMA
    || ' TO ROLE OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL';
  -- The connector MERGEs into tables it created; it owns them via the execute-as role.

  RETURN 'OK: ' || :V_SCHEMA || ' ready. Next: add ' || :V_DOMAIN
      || ':443 to the network rule, then install the connector on the canvas with '
      || 'Destination Database=SHOPIFY_RAW, Destination Schema=' || :V_KEY || '.';
END;
$$;

-- 2. Create schemas for every registered store ---------------------------------
--    Safe to re-run after adding stores to the registry.
CREATE OR REPLACE PROCEDURE SHOPIFY_RAW.PUBLIC.CREATE_ALL_STORE_SCHEMAS()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Calls CREATE_STORE_SCHEMA for every store in the shared registry.'
EXECUTE AS CALLER
AS
$$
DECLARE
  V_STORES RESULTSET;
  V_RESULT VARCHAR;
  V_KEY    VARCHAR;
  V_N      INTEGER DEFAULT 0;
BEGIN
  V_STORES := (SELECT STORE_KEY FROM SHOPIFY_CONTROL.META.STORE_REGISTRY ORDER BY STORE_KEY);
  FOR REC IN V_STORES DO
    V_KEY := REC.STORE_KEY;
    CALL SHOPIFY_RAW.PUBLIC.CREATE_STORE_SCHEMA(:V_KEY) INTO :V_RESULT;
    V_N := V_N + 1;
  END FOR;
  RETURN 'OK: processed ' || :V_N || ' registered stores.';
END;
$$;

CALL SHOPIFY_RAW.PUBLIC.CREATE_ALL_STORE_SCHEMAS();

-- 3. After the canvas install, record it so freshness can tell ----------------
--    "never installed" apart from "installed but broken".
-- UPDATE SHOPIFY_CONTROL.META.STORE_REGISTRY
--    SET CONNECTOR_INSTALLED_AT = CURRENT_TIMESTAMP()
--  WHERE STORE_KEY = 'STORE_ALPHA';

-- 4. Verify -------------------------------------------------------------------
SELECT STORE_KEY, SHOP_DOMAIN, IS_ACTIVE, QUALIFICATION_STATUS, CONNECTOR_INSTALLED_AT
FROM SHOPIFY_CONTROL.META.STORE_REGISTRY
ORDER BY STORE_KEY;

SHOW SCHEMAS IN DATABASE SHOPIFY_RAW;
