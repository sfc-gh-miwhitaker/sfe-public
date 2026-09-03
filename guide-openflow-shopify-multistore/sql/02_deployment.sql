/*
  guide-openflow-shopify-multistore — 02_deployment.sql
  Pair-programmed by SE Community + Cortex Code
  Expires: 2026-12-03

  PURPOSE
    Create the Openflow Snowflake Deployment (gen 2). A deployment is the data
    plane container; every runtime lives inside one. Snowflake operates the
    control plane. Provisioning is asynchronous (typically 5-10 minutes).

  RUN AS      OPENFLOW_ADMIN
  RUNTIME     command returns immediately; wait call blocks up to 15 minutes
  SOURCE      https://docs.snowflake.com/en/sql-reference/sql/create-openflow-deployment
              https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-spcs-deployment

  COST NOTE
    Creating a deployment starts the Openflow Management Services compute pool
    (one CPU_X64_S node). It bills continuously for as long as the deployment
    exists -- even with zero runtimes running. See 07_monitoring.sql.

  LIMITS
    Max 3 Snowflake deployments per account (gen 1 and gen 2 share the limit).
    Not available in trial accounts without a request to your account team.

  -- syntax from docs, not executed: Openflow DDL cannot be compile-checked
  -- outside an Openflow-enabled account.
*/

USE ROLE OPENFLOW_ADMIN;

CREATE OPENFLOW DEPLOYMENT IF NOT EXISTS SHOPIFY_DEPLOYMENT
  DEPLOYMENT_TYPE = SNOWFLAKE
  EVENT_TABLE     = 'OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_EVENTS'
  DISPLAY_NAME    = 'Shopify multi-store ingestion'
  COMMENT         = 'Openflow Snowflake Deployment hosting the Shopify connector fleet';

-- Block until ACTIVE (timeout in seconds). Re-run if it times out.
SELECT SYSTEM$WAIT_FOR_OPENFLOW_DEPLOYMENT_STATUS('SHOPIFY_DEPLOYMENT', 'ACTIVE', 900);

-- Verify
SHOW OPENFLOW DEPLOYMENTS;
DESCRIBE OPENFLOW DEPLOYMENT SHOPIFY_DEPLOYMENT;
SHOW PARAMETERS LIKE 'EVENT_TABLE' IN OPENFLOW DEPLOYMENT SHOPIFY_DEPLOYMENT;
