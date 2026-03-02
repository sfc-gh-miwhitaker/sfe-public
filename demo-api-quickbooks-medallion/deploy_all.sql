/*==============================================================================
DEPLOY_ALL.SQL
QuickBooks API Medallion Architecture Demo
Single entry point -- run this file to deploy the entire demo.

Usage modes:
  1. SAMPLE DATA (no QBO creds): Run sections 1, 3, 4, 5, 6, 7, 8, 9
     Skip section 2 (network/auth) and use 04_sample_data.sql instead
  2. LIVE API: Run all sections in order, then configure OAuth and task

Author: SE Community | Expires: 2026-03-29
==============================================================================*/

-------------------------------------------------------------------------------
-- 0. EXPIRATION CHECK
-------------------------------------------------------------------------------
SET demo_expiry = '2026-03-29'::DATE;
SELECT
    CASE
        WHEN CURRENT_DATE() > $demo_expiry
        THEN 'WARNING: This demo expired on ' || $demo_expiry || '. Please check for an updated version.'
        ELSE 'Demo valid until ' || $demo_expiry || ' (' || DATEDIFF('day', CURRENT_DATE(), $demo_expiry) || ' days remaining)'
    END AS expiration_status;

-------------------------------------------------------------------------------
-- 1. SETUP: Schema, warehouse, role grants
-------------------------------------------------------------------------------
-- sql/01_setup/01_create_schema.sql

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

-------------------------------------------------------------------------------
-- 2. BRONZE: Network/Auth (SKIP for sample-data-only mode)
--    Uncomment this section if you have QBO OAuth credentials.
--    See docs/02-API-SETUP.md for instructions.
-------------------------------------------------------------------------------
/*
USE ROLE ACCOUNTADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

CREATE OR REPLACE NETWORK RULE SFE_QBO_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = (
        'sandbox-quickbooks.api.intuit.com',
        'quickbooks.api.intuit.com',
        'oauth.platform.intuit.com'
    )
    COMMENT = 'DEMO: Egress to QBO REST API and OAuth (Expires: 2026-03-29)';

CREATE OR REPLACE SECURITY INTEGRATION SFE_QBO_OAUTH_INTEGRATION
    TYPE = API_AUTHENTICATION
    AUTH_TYPE = OAUTH2
    OAUTH_CLIENT_ID = '<YOUR_INTUIT_CLIENT_ID>'
    OAUTH_CLIENT_SECRET = '<YOUR_INTUIT_CLIENT_SECRET>'
    OAUTH_TOKEN_ENDPOINT = 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'
    OAUTH_AUTHORIZATION_ENDPOINT = 'https://appcenter.intuit.com/connect/oauth2'
    OAUTH_ALLOWED_SCOPES = ('com.intuit.quickbooks.accounting')
    ENABLED = TRUE
    COMMENT = 'DEMO: QBO OAuth2 security integration (Expires: 2026-03-29)';

CREATE OR REPLACE SECRET SFE_QBO_OAUTH_SECRET
    TYPE = OAUTH2
    API_AUTHENTICATION = SFE_QBO_OAUTH_INTEGRATION
    COMMENT = 'DEMO: QBO OAuth2 refresh token (Expires: 2026-03-29)';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SFE_QBO_API_INTEGRATION
    ALLOWED_NETWORK_RULES = (SFE_QBO_NETWORK_RULE)
    ALLOWED_AUTHENTICATION_SECRETS = (SFE_QBO_OAUTH_SECRET)
    ENABLED = TRUE
    COMMENT = 'DEMO: External access for QBO API calls (Expires: 2026-03-29)';

GRANT READ ON SECRET SFE_QBO_OAUTH_SECRET TO ROLE SYSADMIN;
GRANT USAGE ON INTEGRATION SFE_QBO_API_INTEGRATION TO ROLE SYSADMIN;

USE ROLE SYSADMIN;
*/

-------------------------------------------------------------------------------
-- 3. BRONZE: Raw tables
-------------------------------------------------------------------------------

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

CREATE TABLE IF NOT EXISTS RAW_CUSTOMER (
    qbo_id VARCHAR NOT NULL, raw_payload VARIANT NOT NULL,
    fetched_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(), api_endpoint VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Customer JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_VENDOR (
    qbo_id VARCHAR NOT NULL, raw_payload VARIANT NOT NULL,
    fetched_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(), api_endpoint VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Vendor JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_ITEM (
    qbo_id VARCHAR NOT NULL, raw_payload VARIANT NOT NULL,
    fetched_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(), api_endpoint VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Item JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_ACCOUNT (
    qbo_id VARCHAR NOT NULL, raw_payload VARIANT NOT NULL,
    fetched_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(), api_endpoint VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Account JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_INVOICE (
    qbo_id VARCHAR NOT NULL, raw_payload VARIANT NOT NULL,
    fetched_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(), api_endpoint VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Invoice JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_PAYMENT (
    qbo_id VARCHAR NOT NULL, raw_payload VARIANT NOT NULL,
    fetched_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(), api_endpoint VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Payment JSON (Expires: 2026-03-29)';

CREATE TABLE IF NOT EXISTS RAW_BILL (
    qbo_id VARCHAR NOT NULL, raw_payload VARIANT NOT NULL,
    fetched_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(), api_endpoint VARCHAR
) COMMENT = 'DEMO: Raw QuickBooks Bill JSON (Expires: 2026-03-29)';

-------------------------------------------------------------------------------
-- 4. BRONZE: Sample data (for offline demo mode)
--    This populates Bronze tables with synthetic data including intentional
--    quality issues that DMFs will detect.
-------------------------------------------------------------------------------
-- Run: sql/02_bronze/04_sample_data.sql
-- (Too large to inline here -- execute the file directly)

-------------------------------------------------------------------------------
-- 5. SILVER: Dynamic tables (JSON path extraction)
--    These create automatically-refreshing typed tables from raw JSON.
-------------------------------------------------------------------------------
-- Run: sql/03_silver/01_dynamic_tables.sql

-------------------------------------------------------------------------------
-- 6. SILVER: Cortex enrichment (AI in dynamic tables)
--    AI_SENTIMENT, AI_CLASSIFY, AI_COMPLETE in incremental refresh mode.
-------------------------------------------------------------------------------
-- Run: sql/03_silver/02_cortex_enrichment.sql

-------------------------------------------------------------------------------
-- 7. GOLD: Analytics views
-------------------------------------------------------------------------------
-- Run: sql/04_gold/01_analytics_views.sql

-------------------------------------------------------------------------------
-- 8. GOLD: Cortex insights (AI-powered dynamic tables)
-------------------------------------------------------------------------------
-- Run: sql/04_gold/02_cortex_insights.sql

-------------------------------------------------------------------------------
-- 9. DATA QUALITY: System DMFs + Custom DMFs + Notifications + Dashboard
-------------------------------------------------------------------------------
-- Run in order:
--   sql/05_data_quality/01_system_dmfs.sql
--   sql/05_data_quality/02_custom_dmfs.sql
--   sql/05_data_quality/03_notifications.sql   (requires ACCOUNTADMIN)
--   sql/05_data_quality/04_quality_dashboard.sql

-------------------------------------------------------------------------------
-- 10. ORCHESTRATION: Task for live API mode (skip for sample data)
-------------------------------------------------------------------------------
-- Run: sql/06_orchestration/01_tasks.sql

SELECT 'Deploy complete! Run the sample data script next: sql/02_bronze/04_sample_data.sql' AS next_step;
