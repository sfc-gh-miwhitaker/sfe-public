/*==============================================================================
TEARDOWN_ALL.SQL
QuickBooks API Medallion Architecture Demo
Complete cleanup of all demo objects. Run when the demo is no longer needed.
Author: SE Community | Expires: 2026-05-01
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-------------------------------------------------------------------------------
-- 1. Drop the task first (must be done before dependent objects)
-------------------------------------------------------------------------------
DROP TASK IF EXISTS SNOWFLAKE_EXAMPLE.QB_API.FETCH_QBO_ENTITIES_TASK;

-------------------------------------------------------------------------------
-- 2. Drop notification integrations
-------------------------------------------------------------------------------
DROP NOTIFICATION INTEGRATION IF EXISTS SFE_DQ_EMAIL_INT;
DROP NOTIFICATION INTEGRATION IF EXISTS SFE_DQ_SLACK_INT;

-------------------------------------------------------------------------------
-- 3. Drop external access integration and security objects
-------------------------------------------------------------------------------
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS SFE_QBO_API_INTEGRATION;
DROP SECURITY INTEGRATION IF EXISTS SFE_QBO_OAUTH_INTEGRATION;
DROP NETWORK RULE IF EXISTS SNOWFLAKE_EXAMPLE.QB_API.SFE_QBO_NETWORK_RULE;

-------------------------------------------------------------------------------
-- 4. Clear database-level DQ monitoring settings
-------------------------------------------------------------------------------
ALTER DATABASE SNOWFLAKE_EXAMPLE UNSET DATA_QUALITY_MONITORING_SETTINGS;

-------------------------------------------------------------------------------
-- 5. Drop the schema (cascades all tables, views, dynamic tables, DMFs,
--    stored procedures, secrets, and watermark table)
-------------------------------------------------------------------------------
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.QB_API CASCADE;

-------------------------------------------------------------------------------
-- 6. Drop the warehouse
-------------------------------------------------------------------------------
DROP WAREHOUSE IF EXISTS SFE_QB_API_WH;

-------------------------------------------------------------------------------
-- 7. Drop the database only if it has no other schemas
--    (SNOWFLAKE_EXAMPLE may be shared across demos)
-------------------------------------------------------------------------------
-- Uncomment the following line if you want to remove the entire database:
-- DROP DATABASE IF EXISTS SNOWFLAKE_EXAMPLE;

USE ROLE SYSADMIN;

SELECT 'Teardown complete. All QB_API demo objects have been removed.' AS status;
