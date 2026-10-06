/*
  guide-shopify-multistore-snowflake — sql/openflow/03_execute_as_role_eai.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-21

  PURPOSE
    Create the objects a runtime needs before it can reach Shopify and write
    to Snowflake:
      - the execute-as role (connectors run with this role's privileges)
      - an ingestion warehouse the connector uses for CREATE TABLE / MERGE
      - a network rule listing EVERY store domain + Shopify's GCS result host
      - an external access integration (EAI) wrapping that rule

  RUN AS      ACCOUNTADMIN for role/EAI creation; OPENFLOW_ADMIN for the rest
  RUNTIME     < 1 minute
  SOURCE      https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-spcs-create-rr
              https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/setup

  MULTI-STORE RULE
    The network rule VALUE_LIST must include <store>.myshopify.com:443 for each
    store. Adding a store later = ALTER NETWORK RULE ... SET VALUE_LIST with the
    FULL list. NEVER use CREATE OR REPLACE on the rule or the EAI: replacing
    either silently detaches it from every runtime that references it.
    (The Shopify setup page's sample uses CREATE OR REPLACE; the general
    Openflow setup docs say not to. This file follows the safe form.)

    SHOPIFY_CONTROL.META.NETWORK_RULE_VALUE_LIST emits the full paste-ready
    list from the shared registry. Use it rather than hand-maintaining this list.

  ALLOWLIST NOTE
    This is an EGRESS rule: it constrains what the runtime may call. It has
    nothing to do with Shopify allowlisting Snowflake. Snowflake does not
    publish a stable egress IP range for Openflow Snowflake Deployments, so if
    a store restricts inbound API access by IP, this path cannot satisfy it.
*/

-- 1. Execute-as role ----------------------------------------------------------
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL
  COMMENT = 'Execute-as role for the Shopify Openflow runtime';

GRANT ROLE OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL TO ROLE OPENFLOW_ADMIN;

-- 2. Ingestion warehouse ------------------------------------------------------
--    Used only for table management (CREATE TABLE, MERGE). Data movement is
--    Snowpipe Streaming, billed separately. Keep it small and auto-suspending.
CREATE WAREHOUSE IF NOT EXISTS SHOPIFY_INGEST_WH
  WAREHOUSE_SIZE               = 'XSMALL'
  AUTO_SUSPEND                 = 60
  AUTO_RESUME                  = TRUE
  INITIALLY_SUSPENDED          = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 1800
  COMMENT = 'Openflow Shopify connector table management (CREATE TABLE / MERGE)';

GRANT USAGE, OPERATE ON WAREHOUSE SHOPIFY_INGEST_WH
  TO ROLE OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL;

-- 3. Network rule: one entry per store + Shopify bulk-result host -------------
--    Replace the example store domains with your real ones, or paste the output
--    of SHOPIFY_CONTROL.META.NETWORK_RULE_VALUE_LIST.
USE ROLE OPENFLOW_ADMIN;
USE SCHEMA OPENFLOW_DB.OPENFLOW_SCHEMA;

CREATE NETWORK RULE IF NOT EXISTS OPENFLOW_SHOPIFY_RUNTIME_NETWORK_RULE
  TYPE       = HOST_PORT
  MODE       = EGRESS
  VALUE_LIST = (
    'storage.googleapis.com:443',          -- Shopify bulk-operation JSONL downloads (required)
    'store-alpha.myshopify.com:443',       -- store 1
    'store-bravo.myshopify.com:443',       -- store 2
    'store-charlie.myshopify.com:443'      -- store 3 ... add one line per store
  )
  COMMENT = 'Shopify Admin GraphQL API for every store + GCS bulk result host';

-- To ADD a store later, restate the FULL list from the registry view:
--   SELECT VALUE_LIST FROM SHOPIFY_CONTROL.META.NETWORK_RULE_VALUE_LIST;
--   ALTER NETWORK RULE OPENFLOW_SHOPIFY_RUNTIME_NETWORK_RULE
--     SET VALUE_LIST = ( ...pasted... );

-- 4. External access integration ----------------------------------------------
USE ROLE ACCOUNTADMIN;

CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS OPENFLOW_SHOPIFY_RUNTIME_EAI
  ALLOWED_NETWORK_RULES = (OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_SHOPIFY_RUNTIME_NETWORK_RULE)
  ENABLED = TRUE
  COMMENT = 'Lets the Shopify Openflow runtime reach Shopify and GCS';

GRANT USAGE ON INTEGRATION OPENFLOW_SHOPIFY_RUNTIME_EAI
  TO ROLE OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL;

-- 5. Verify -------------------------------------------------------------------
DESCRIBE NETWORK RULE OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_SHOPIFY_RUNTIME_NETWORK_RULE;
DESCRIBE EXTERNAL ACCESS INTEGRATION OPENFLOW_SHOPIFY_RUNTIME_EAI;
