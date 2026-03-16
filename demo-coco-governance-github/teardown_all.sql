/*==============================================================================
TEARDOWN ALL - GitHub-Powered Project Tooling for Cortex Code
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-15
INSTRUCTIONS: Open in Snowsight -> Click "Run All"
==============================================================================*/

USE ROLE ACCOUNTADMIN;

DROP TABLE IF EXISTS SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB.ORDERS;
DROP TABLE IF EXISTS SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB.PRODUCTS;
DROP TABLE IF EXISTS SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB.CUSTOMERS;
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB;
DROP WAREHOUSE IF EXISTS SFE_COCO_GOVERNANCE_GITHUB_WH;

SELECT 'Teardown complete!' AS status, CURRENT_TIMESTAMP() AS completed_at;
