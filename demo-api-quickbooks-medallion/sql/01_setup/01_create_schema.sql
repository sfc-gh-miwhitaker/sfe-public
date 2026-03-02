/*==============================================================================
01_SETUP / 01_CREATE_SCHEMA
QuickBooks API Medallion Architecture Demo
Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.QB_API
    COMMENT = 'DEMO: QuickBooks API medallion architecture with Cortex AI enrichment and DMF quality monitoring (Expires: 2026-03-29)';

CREATE WAREHOUSE IF NOT EXISTS SFE_QB_API_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'DEMO: QuickBooks API demo compute (Expires: 2026-03-29)';

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;
USE WAREHOUSE SFE_QB_API_WH;

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SYSADMIN;
GRANT DATABASE ROLE SNOWFLAKE.DATA_METRIC_USER TO ROLE SYSADMIN;
