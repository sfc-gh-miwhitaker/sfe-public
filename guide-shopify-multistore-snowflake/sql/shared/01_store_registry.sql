/*
  guide-shopify-multistore-snowflake — sql/shared/01_store_registry.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    The one store registry both implementation paths read. Whichever path you
    choose (Openflow connector or native Bulk API + CoCo), this is the single
    source of truth for which Shopify stores exist, who owns them, and whether
    they have passed qualification.

    Deploy this FIRST, before any path-specific script.

  WHY IT IS SHARED
    Both paths need the same answers: which stores are in scope, which are live,
    which have been reconciled against the incumbent. Keeping one registry means
    the monitoring queries, the cutover checklist, and the freshness contract are
    identical on both paths -- and a path migration does not rewrite them.

  PATH-SPECIFIC COLUMNS
    credential_object_fqn is NULL on the Openflow path. That path stores the
    Shopify Client ID/Secret as sensitive connector parameters on the NiFi
    canvas, not as Snowflake SECRET objects, so there is no FQN to record.
    The native path requires it (see sql/native/02_network_secrets.sql).

  RUN AS      ACCOUNTADMIN for the role grant, then SHOPIFY_CONTROL_ADMIN
  RUNTIME     < 1 minute
*/

USE ROLE ACCOUNTADMIN;

-- 1. Owner role for the shared control objects --------------------------------
CREATE ROLE IF NOT EXISTS SHOPIFY_CONTROL_ADMIN
  COMMENT = 'Owns the shared Shopify store registry and cutover baseline';

GRANT ROLE SHOPIFY_CONTROL_ADMIN TO ROLE SYSADMIN;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE SHOPIFY_CONTROL_ADMIN;

USE ROLE SHOPIFY_CONTROL_ADMIN;

CREATE DATABASE IF NOT EXISTS SHOPIFY_CONTROL
  COMMENT = 'Path-independent Shopify control plane: store registry, cutover baseline, published contract views';

CREATE SCHEMA IF NOT EXISTS SHOPIFY_CONTROL.META
  COMMENT = 'Store registry, registration procedure, and the published analytics contract views';

-- 2. Registry ------------------------------------------------------------------
--    Reconciled union of both former guides' registries.
CREATE TABLE IF NOT EXISTS SHOPIFY_CONTROL.META.STORE_REGISTRY (
  STORE_KEY              VARCHAR(64)   NOT NULL,           -- uppercase [A-Z0-9_]; also the Openflow destination schema name
  SHOP_DOMAIN            VARCHAR(255)  NOT NULL,           -- <store>.myshopify.com
  DISPLAY_NAME           VARCHAR(255),                     -- human label for reports
  BUSINESS_OWNER         VARCHAR(255),                     -- who answers "is this store still live?"
  SHOPIFY_PLAN           VARCHAR(64),                      -- affects Shopify API rate limits
  IS_ACTIVE              BOOLEAN       NOT NULL DEFAULT FALSE,   -- FALSE until qualification passes
  QUALIFICATION_STATUS   VARCHAR(32)   NOT NULL DEFAULT 'NOT_RUN',
  CREDENTIAL_OBJECT_FQN  VARCHAR(255),                     -- native path only; NULL on the Openflow path
  CONNECTOR_INSTALLED_AT TIMESTAMP_TZ,                     -- Openflow path: set after the canvas install
  LAST_QUALIFIED_AT      TIMESTAMP_TZ,
  REGISTERED_AT          TIMESTAMP_TZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  CONSTRAINT PK_STORE_REGISTRY PRIMARY KEY (STORE_KEY),
  CONSTRAINT UQ_STORE_DOMAIN   UNIQUE (SHOP_DOMAIN)
)
COMMENT = 'Source of truth for which Shopify stores are ingested, on either implementation path';

-- 3. Cutover baseline ----------------------------------------------------------
--    Load the incumbent ELT tool's daily numbers here before cutover. Both
--    paths reconcile against it; the native path's QUALIFY_STORE reads it
--    directly.
CREATE TABLE IF NOT EXISTS SHOPIFY_CONTROL.META.RECONCILIATION_BASELINE (
  STORE_KEY     VARCHAR(64) NOT NULL,
  ACTIVITY_DATE DATE        NOT NULL,
  SOURCE_NAME   VARCHAR(64) NOT NULL,       -- name of the incumbent, e.g. 'INCUMBENT_ELT'
  ORDER_COUNT   NUMBER,
  GROSS_SALES   NUMBER(38,4),
  CURRENCY_CODE VARCHAR(16),
  CAPTURED_AT   TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Incumbent pipeline daily totals, used to reconcile before cutover';

-- 4. ADD_STORE: validate and register -----------------------------------------
--    Registration only. It deliberately does NOT activate the store: activation
--    is an explicit statement after qualification evidence has been reviewed.
--    The Openflow path calls sql/openflow/05_store_schemas.sql afterwards to
--    create the store's landing schema.
CREATE OR REPLACE PROCEDURE SHOPIFY_CONTROL.META.ADD_STORE(
  P_STORE_KEY             VARCHAR,
  P_SHOP_DOMAIN           VARCHAR,
  P_BUSINESS_OWNER        VARCHAR,
  P_DISPLAY_NAME          VARCHAR DEFAULT NULL,
  P_SHOPIFY_PLAN          VARCHAR DEFAULT NULL,
  P_CREDENTIAL_OBJECT_FQN VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Registers a Shopify store as INACTIVE pending qualification. Idempotent. Path-independent.'
EXECUTE AS CALLER
AS
$$
DECLARE
  V_KEY VARCHAR;
BEGIN
  V_KEY := UPPER(:P_STORE_KEY);

  IF (NOT REGEXP_LIKE(:V_KEY, '^[A-Z][A-Z0-9_]{0,62}$')) THEN
    RETURN 'ERROR: store_key must match ^[A-Z][A-Z0-9_]{0,62}$ (got ' || :P_STORE_KEY
        || '). Fix: use a leading letter then letters, digits, or underscore only.';
  END IF;

  IF (NOT REGEXP_LIKE(LOWER(:P_SHOP_DOMAIN), '^[a-z0-9-]+\\.myshopify\\.com$')) THEN
    RETURN 'ERROR: shop_domain must be <store>.myshopify.com (got ' || :P_SHOP_DOMAIN
        || '). Fix: use the permanent myshopify domain, not a custom storefront domain.';
  END IF;

  IF (:P_CREDENTIAL_OBJECT_FQN IS NOT NULL
      AND NOT REGEXP_LIKE(UPPER(:P_CREDENTIAL_OBJECT_FQN),
                          '^[A-Z][A-Z0-9_$]*\\.[A-Z][A-Z0-9_$]*\\.[A-Z][A-Z0-9_$]*$')) THEN
    RETURN 'ERROR: credential_object_fqn must be DATABASE.SCHEMA.SECRET (got '
        || :P_CREDENTIAL_OBJECT_FQN || '). Fix: pass the fully qualified secret name, or NULL on the Openflow path.';
  END IF;

  MERGE INTO SHOPIFY_CONTROL.META.STORE_REGISTRY AS T
  USING (
    SELECT :V_KEY                              AS STORE_KEY,
           LOWER(:P_SHOP_DOMAIN)               AS SHOP_DOMAIN,
           :P_DISPLAY_NAME                     AS DISPLAY_NAME,
           :P_BUSINESS_OWNER                   AS BUSINESS_OWNER,
           :P_SHOPIFY_PLAN                     AS SHOPIFY_PLAN,
           UPPER(:P_CREDENTIAL_OBJECT_FQN)     AS CREDENTIAL_OBJECT_FQN
  ) AS S
     ON T.STORE_KEY = S.STORE_KEY
  WHEN MATCHED THEN UPDATE SET
       SHOP_DOMAIN           = S.SHOP_DOMAIN,
       DISPLAY_NAME          = S.DISPLAY_NAME,
       BUSINESS_OWNER        = S.BUSINESS_OWNER,
       SHOPIFY_PLAN          = S.SHOPIFY_PLAN,
       CREDENTIAL_OBJECT_FQN = COALESCE(S.CREDENTIAL_OBJECT_FQN, T.CREDENTIAL_OBJECT_FQN)
  WHEN NOT MATCHED THEN INSERT
       (STORE_KEY, SHOP_DOMAIN, DISPLAY_NAME, BUSINESS_OWNER, SHOPIFY_PLAN, CREDENTIAL_OBJECT_FQN)
  VALUES
       (S.STORE_KEY, S.SHOP_DOMAIN, S.DISPLAY_NAME, S.BUSINESS_OWNER, S.SHOPIFY_PLAN, S.CREDENTIAL_OBJECT_FQN);

  RETURN 'OK: ' || :V_KEY || ' registered as INACTIVE. Next: run the path-specific setup, '
      || 'qualify the store, then set IS_ACTIVE = TRUE only after every gate passes.';
END;
$$;

-- 5. Register the example stores (edit to your stores) -------------------------
CALL SHOPIFY_CONTROL.META.ADD_STORE('STORE_ALPHA',   'store-alpha.myshopify.com',   'merch-analytics@example.com', 'Alpha Apparel',  'Shopify Plus');
CALL SHOPIFY_CONTROL.META.ADD_STORE('STORE_BRAVO',   'store-bravo.myshopify.com',   'merch-analytics@example.com', 'Bravo Outdoors', 'Advanced');
CALL SHOPIFY_CONTROL.META.ADD_STORE('STORE_CHARLIE', 'store-charlie.myshopify.com', 'merch-analytics@example.com', 'Charlie Home',   'Advanced');

-- 6. Openflow path helper: paste-ready network rule VALUE_LIST -----------------
--    The native path uses a single wildcard rule instead and does not need this.
CREATE OR REPLACE VIEW SHOPIFY_CONTROL.META.NETWORK_RULE_VALUE_LIST
COMMENT = 'Paste-ready VALUE_LIST for the Openflow Shopify network rule, derived from active stores'
AS
SELECT '(' || LISTAGG(ENTRY, ', ') WITHIN GROUP (ORDER BY ENTRY) || ')' AS VALUE_LIST
FROM (
  SELECT '''storage.googleapis.com:443''' AS ENTRY
  UNION ALL
  SELECT '''' || SHOP_DOMAIN || ':443'''
  FROM SHOPIFY_CONTROL.META.STORE_REGISTRY
  WHERE IS_ACTIVE
);

-- 7. Verify --------------------------------------------------------------------
SELECT STORE_KEY, SHOP_DOMAIN, DISPLAY_NAME, BUSINESS_OWNER, SHOPIFY_PLAN,
       IS_ACTIVE, QUALIFICATION_STATUS, CREDENTIAL_OBJECT_FQN
FROM SHOPIFY_CONTROL.META.STORE_REGISTRY
ORDER BY STORE_KEY;
