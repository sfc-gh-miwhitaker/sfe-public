/*
  guide-openflow-shopify-multistore — 05_store_schemas.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-03

  PURPOSE
    The landing zone. One database (SHOPIFY_RAW), one schema per store, all
    generated from a STORE_REGISTRY table so adding store #23 is one CALL, not
    a hand-edited script.

  WHY ONE SCHEMA PER STORE
    The connector creates tables named ORDERS, PRODUCTS, ... in whatever
    Destination Schema you give it. Snowflake docs confirm the merge key is
    (ID, SHOP_URL), which suggests a shared table could work, but there is no
    doc statement that multiple connector instances writing the same table is
    supported. One schema per store is the path with no undocumented behaviour:
    blast radius is one store, a state reset drops one store's tables, and the
    analytics layer UNION ALLs across schemas (06_analytics_layer.sql).

  RUN AS      OPENFLOW_ADMIN (owns SHOPIFY_RAW)
  RUNTIME     < 1 minute
*/

USE ROLE OPENFLOW_ADMIN;

CREATE DATABASE IF NOT EXISTS SHOPIFY_RAW
  COMMENT = 'Raw Shopify data landed by Openflow; one schema per store';

CREATE SCHEMA IF NOT EXISTS SHOPIFY_RAW.META
  COMMENT = 'Store registry and generator procedures';

GRANT USAGE ON DATABASE SHOPIFY_RAW TO ROLE OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL;

-- 1. Registry -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SHOPIFY_RAW.META.STORE_REGISTRY (
  store_key       VARCHAR(64)   NOT NULL,   -- schema name; uppercase [A-Z0-9_]
  shop_domain     VARCHAR(255)  NOT NULL,   -- e.g. store-alpha.myshopify.com
  display_name    VARCHAR(255),
  business_owner  VARCHAR(255),             -- who answers "is this store still live?"
  shopify_plan    VARCHAR(64),              -- affects API rate limits
  is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
  connector_installed_at TIMESTAMP_NTZ,     -- set manually after canvas install
  registered_at   TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  CONSTRAINT pk_store_registry PRIMARY KEY (store_key),
  CONSTRAINT uq_shop_domain    UNIQUE (shop_domain)
)
COMMENT = 'Source of truth for which Shopify stores are ingested. Drives schema creation and analytics DTs.';

-- 2. ADD_STORE: register + create schema + grant --------------------------------
CREATE OR REPLACE PROCEDURE SHOPIFY_RAW.META.ADD_STORE(
  p_store_key      VARCHAR,
  p_shop_domain    VARCHAR,
  p_business_owner VARCHAR,
  p_display_name   VARCHAR DEFAULT NULL,
  p_shopify_plan   VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Registers a store, creates SHOPIFY_RAW.<STORE_KEY>, grants the execute-as role. Idempotent.'
EXECUTE AS CALLER
AS
$$
DECLARE
  v_key    VARCHAR;
  v_schema VARCHAR;
BEGIN
  v_key := UPPER(:p_store_key);
  IF (NOT REGEXP_LIKE(:v_key, '^[A-Z][A-Z0-9_]{0,62}$')) THEN
    RETURN 'ERROR: store_key must match ^[A-Z][A-Z0-9_]{0,62}$ (got ' || :p_store_key || '). Fix: use letters, digits, underscore only.';
  END IF;
  IF (NOT REGEXP_LIKE(LOWER(:p_shop_domain), '^[a-z0-9-]+\\.myshopify\\.com$')) THEN
    RETURN 'ERROR: shop_domain must be <store>.myshopify.com (got ' || :p_shop_domain || ').';
  END IF;

  MERGE INTO SHOPIFY_RAW.META.STORE_REGISTRY t
  USING (SELECT :v_key AS store_key, LOWER(:p_shop_domain) AS shop_domain,
                :p_display_name AS display_name, :p_business_owner AS business_owner,
                :p_shopify_plan AS shopify_plan) s
     ON t.store_key = s.store_key
  WHEN MATCHED THEN UPDATE SET
       shop_domain = s.shop_domain, display_name = s.display_name,
       business_owner = s.business_owner, shopify_plan = s.shopify_plan, is_active = TRUE
  WHEN NOT MATCHED THEN INSERT (store_key, shop_domain, display_name, business_owner, shopify_plan)
       VALUES (s.store_key, s.shop_domain, s.display_name, s.business_owner, s.shopify_plan);

  v_schema := 'SHOPIFY_RAW.' || :v_key;
  EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS ' || :v_schema
    || ' COMMENT = ''Openflow Shopify landing for ' || LOWER(:p_shop_domain) || '''';
  EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA ' || :v_schema
    || ' TO ROLE OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL';
  EXECUTE IMMEDIATE 'GRANT CREATE TABLE ON SCHEMA ' || :v_schema
    || ' TO ROLE OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL';
  -- Connector MERGEs into tables it created; it owns them via the execute-as role.

  RETURN 'OK: ' || :v_schema || ' ready. Next: add ' || LOWER(:p_shop_domain)
    || ':443 to the network rule, then install the connector on the canvas with '
    || 'Destination Database=SHOPIFY_RAW, Destination Schema=' || :v_key || '.';
END;
$$;

-- 3. Register the pilot store and two more (edit to your stores) ----------------
CALL SHOPIFY_RAW.META.ADD_STORE('STORE_ALPHA',   'store-alpha.myshopify.com',   'merch-analytics@example.com', 'Alpha Apparel', 'Shopify Plus');
CALL SHOPIFY_RAW.META.ADD_STORE('STORE_BRAVO',   'store-bravo.myshopify.com',   'merch-analytics@example.com', 'Bravo Outdoors', 'Advanced');
CALL SHOPIFY_RAW.META.ADD_STORE('STORE_CHARLIE', 'store-charlie.myshopify.com', 'merch-analytics@example.com', 'Charlie Home', 'Advanced');

-- 4. Helper: emit the network-rule VALUE_LIST from the registry ----------------
--    Copy the output into ALTER NETWORK RULE ... SET VALUE_LIST (03_execute_as_role_eai.sql).
CREATE OR REPLACE VIEW SHOPIFY_RAW.META.NETWORK_RULE_VALUE_LIST
COMMENT = 'Paste-ready VALUE_LIST for the Shopify network rule, derived from active stores'
AS
SELECT
  '(' || LISTAGG(entry, ', ') WITHIN GROUP (ORDER BY entry) || ')' AS value_list
FROM (
  SELECT '''storage.googleapis.com:443''' AS entry
  UNION ALL
  SELECT '''' || shop_domain || ':443'''
  FROM SHOPIFY_RAW.META.STORE_REGISTRY
  WHERE is_active
);

SELECT value_list FROM SHOPIFY_RAW.META.NETWORK_RULE_VALUE_LIST;

-- 5. Verify -------------------------------------------------------------------
SELECT store_key, shop_domain, is_active, connector_installed_at
FROM SHOPIFY_RAW.META.STORE_REGISTRY
ORDER BY store_key;

SHOW SCHEMAS IN DATABASE SHOPIFY_RAW;
