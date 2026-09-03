/*
  guide-openflow-shopify-multistore — 04_runtime.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-03

  PURPOSE
    Create the runtime that will host every Shopify connector process group.
    Provisioning is asynchronous (typically 3-5 minutes).

  RUN AS      OPENFLOW_ADMIN
  SOURCE      https://docs.snowflake.com/en/sql-reference/sql/create-openflow-runtime
              https://docs.snowflake.com/en/user-guide/data-integration/openflow/cost-spcs

  SIZING (facts, then judgment)
    NODE_TYPE is immutable after creation. Sizes: SMALL 1 vCPU/2 GB,
    MEDIUM 4 vCPU/10 GB, LARGE 8 vCPU/20 GB. Nodes 1-50.
    Snowflake publishes packing guidance for CDC connectors only
    (MEDIUM ~5-8 connectors). There is NO published Shopify sizing guidance.
    Starting point used here: MEDIUM, 1-2 nodes, for a pilot plus the first
    ~5-8 stores on a daily sync. Measure runtime CPU/memory/queue depth in the
    event table before adding more; split into a second runtime for blast
    radius rather than scaling one runtime to its ceiling.

  -- syntax from docs, not executed: Openflow DDL cannot be compile-checked
  -- outside an Openflow-enabled account.
*/

USE ROLE OPENFLOW_ADMIN;

CREATE OPENFLOW RUNTIME IF NOT EXISTS OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME
  IN DEPLOYMENT SHOPIFY_DEPLOYMENT
  NODE_TYPE       = MEDIUM
  MIN_NODES       = 1
  MAX_NODES       = 2
  EXECUTE_AS_ROLE = OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL
  EXTERNAL_ACCESS_INTEGRATIONS = (OPENFLOW_SHOPIFY_RUNTIME_EAI)
  DISPLAY_NAME    = 'Shopify stores'
  COMMENT         = 'Hosts one Shopify connector process group per store';

SELECT SYSTEM$WAIT_FOR_OPENFLOW_RUNTIME_STATUS(
  'OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME', 'ACTIVE', 600);

-- Verify and grant read-only visibility to whoever operates the pipeline
SHOW OPENFLOW RUNTIMES IN SCHEMA OPENFLOW_DB.OPENFLOW_SCHEMA;
DESCRIBE OPENFLOW RUNTIME OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME;

-- Optional: let a monitoring role see status without admin rights
-- GRANT MONITOR ON OPENFLOW DEPLOYMENT SHOPIFY_DEPLOYMENT TO ROLE <MONITOR_ROLE>;
-- GRANT MONITOR ON OPENFLOW RUNTIME OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME TO ROLE <MONITOR_ROLE>;

-- Cost lever: suspending the runtime scales its compute pool to 0 nodes.
-- The deployment's Management Services pool keeps billing regardless.
-- ALTER OPENFLOW RUNTIME OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME SUSPEND;
-- ALTER OPENFLOW RUNTIME OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME RESUME;
