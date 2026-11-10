/*==============================================================================
  Sigma Writeback Teardown | Pair-programmed by SE Community + Cortex Code

  INSTRUCTIONS: Open Snowsight -> New Worksheet -> Paste -> Run All.
  Removes only what sql/walkthrough.sql created. Keeps the shared
  SNOWFLAKE_EXAMPLE database and its other schemas.

  WARNING: dropping SIGMA_WRITEBACK deletes every input table Sigma stored
  there. Delete or move the Sigma workbooks that use it first.
==============================================================================*/

USE ROLE ACCOUNTADMIN;

ALTER TASK IF EXISTS SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.SNAPSHOT_REGION_TARGETS SUSPEND;

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS;
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SIGMA_LAB;
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SIGMA_WRITEBACK;

DROP USER IF EXISTS SIGMA_SERVICE_USER;
DROP WAREHOUSE IF EXISTS SFE_SIGMA_WH;
DROP ROLE IF EXISTS SIGMA_DATA_CONSUMER;
DROP ROLE IF EXISTS SIGMA_SERVICE_ROLE;

SELECT 'Sigma writeback guide objects removed' AS status;
