/*****************************************************************************
 * DEMO METADATA (Machine-readable - Do not modify format)
 * PROJECT_NAME: Streamlit DR Replication Cost Calculator
 * AUTHOR: SE Community
 * CREATED: 2025-12-08
 * LAST UPDATED: 2026-03-02
 * EXPIRES: 2026-05-01
 * GITHUB_REPO: https://github.com/sfc-gh-miwhitaker/sfe-public
 * PURPOSE: Snowflake-native replication/DR cost calculator (Streamlit)
 *
 * DEPLOYMENT INSTRUCTIONS:
 * 1. Open Snowsight (https://app.snowflake.com)
 * 2. Ensure you have ACCOUNTADMIN role (required for API integration)
 * 3. Copy this ENTIRE script
 * 4. Paste into a new SQL worksheet
 * 5. Click "Run All" (or press Cmd/Ctrl + Enter repeatedly)
 * 6. Monitor output for any errors
 *
 * ROLE USAGE (Security Best Practice):
 * - ACCOUNTADMIN: Creates API integration only
 * - SYSADMIN: Creates all database objects (owns them)
 * - PUBLIC: Granted SELECT access for demo use
 *****************************************************************************/

-- ============================================================================
-- CONTEXT SETTING (MANDATORY - must precede all operations)
-- ============================================================================
-- ACCOUNTADMIN required for: API Integration only (no external access needed)
-- Drops to SYSADMIN immediately after account-level objects are created.
-- ============================================================================
USE ROLE ACCOUNTADMIN;

-- Ensure a warehouse is available (creates one if user has no default)
EXECUTE IMMEDIATE $$
BEGIN
    IF (CURRENT_WAREHOUSE() IS NULL) THEN
        CREATE WAREHOUSE IF NOT EXISTS SFE_DEMO_DEPLOY_WH
            WAREHOUSE_SIZE = 'XSMALL'
            AUTO_SUSPEND = 60
            AUTO_RESUME = TRUE
            INITIALLY_SUSPENDED = FALSE
            COMMENT = 'Temporary warehouse for demo deployment - safe to drop after deployment';
        USE WAREHOUSE SFE_DEMO_DEPLOY_WH;
    END IF;
END;
$$;

-- SSOT: Change ONLY here, then run: sync-expiration
SET DEMO_EXPIRES = '2026-05-01';

SELECT
    $DEMO_EXPIRES::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) || ' days remaining'
    END AS demo_status;

/*****************************************************************************
 * SECTION 1: Database & Account-Level Objects (ACCOUNTADMIN required)
 *****************************************************************************/
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS GIT_REPOS COMMENT = 'DEMO: Shared Git repos (Expires: 2026-05-01)';

-- API Integration (account-level, no DB context needed)
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = (
        'https://github.com/sfc-gh-miwhitaker/sfe-public'
    )
    ENABLED = TRUE
    COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

CREATE OR REPLACE GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.REPLICATE_THIS_REPO
    API_INTEGRATION = SFE_GIT_API_INTEGRATION
    ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
    COMMENT = 'Source repo for replication cost calc (Expires: 2026-05-01)';

-- Fetch latest code from GitHub
ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.REPLICATE_THIS_REPO FETCH;

-- ============================================================================
-- CONTEXT SWITCH: SYSADMIN for all remaining objects (least privilege)
-- ============================================================================
USE ROLE SYSADMIN;

/*****************************************************************************
 * SECTION 2: Warehouse & Schema (SYSADMIN)
 *****************************************************************************/
CREATE WAREHOUSE IF NOT EXISTS SFE_REPLICATION_CALC_WH
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'DEMO: Replication cost calculator WH (Expires: 2026-05-01)';

-- Set warehouse context for all subsequent operations
USE WAREHOUSE SFE_REPLICATION_CALC_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.REPLICATION_CALC
    COMMENT = 'DEMO: Replication/DR cost calculator (Expires: 2026-05-01)';

USE SCHEMA SNOWFLAKE_EXAMPLE.REPLICATION_CALC;
USE WAREHOUSE SFE_REPLICATION_CALC_WH;

/*****************************************************************************
 * SECTION 3: Streamlit
 *****************************************************************************/
-- Create Streamlit app from Git repository clone (avoid legacy ROOT_LOCATION)
CREATE OR REPLACE STREAMLIT REPLICATION_CALCULATOR
    FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.REPLICATE_THIS_REPO/branches/main/tool-replication-cost-calculator/streamlit
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = SFE_REPLICATION_CALC_WH
    COMMENT = 'DEMO: DR/Replication Cost Calculator (Expires: 2026-05-01)';

/*****************************************************************************
 * SECTION 4: Tables and Views
 *****************************************************************************/
CREATE OR REPLACE TABLE PRICING_CURRENT (
    SERVICE_TYPE STRING,
    CLOUD STRING,
    REGION STRING,
    UNIT STRING,
    RATE NUMBER(10,4),
    CURRENCY STRING,
    UPDATED_AT TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY STRING DEFAULT CURRENT_USER()
) COMMENT = 'Replication pricing rates (BC) - Managed by admins (Expires: 2026-05-01)';

CREATE OR REPLACE VIEW DB_METADATA
    COMMENT = 'DEMO: Database sizes from ACCOUNT_USAGE for replication sizing (Expires: 2026-05-01)'
AS
WITH ALL_DBS AS (
    SELECT DATABASE_NAME
    FROM INFORMATION_SCHEMA.DATABASES
    WHERE DATABASE_NAME NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA', 'UTIL_DB')
),
DB_STORAGE AS (
    SELECT
        TABLE_CATALOG AS DATABASE_NAME,
        SUM(ACTIVE_BYTES) AS TOTAL_BYTES
    FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
    WHERE TABLE_CATALOG NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA', 'UTIL_DB')
      AND DELETED IS NULL
    GROUP BY TABLE_CATALOG
)
SELECT
    d.DATABASE_NAME,
    COALESCE((s.TOTAL_BYTES / POWER(1024, 4)), 0)::NUMBER(18,6) AS SIZE_TB,
    CURRENT_TIMESTAMP() AS AS_OF
FROM ALL_DBS d
LEFT JOIN DB_STORAGE s ON d.DATABASE_NAME = s.DATABASE_NAME;

/*****************************************************************************
 * SECTION 5: Seed Pricing Data
 *****************************************************************************/
-- Insert baseline pricing for AWS, Azure, and GCP regions
INSERT INTO PRICING_CURRENT (SERVICE_TYPE, CLOUD, REGION, UNIT, RATE, CURRENCY) VALUES
    -- AWS Regions
    ('DATA_TRANSFER', 'AWS', 'us-east-1', 'TB', 2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS', 'us-east-1', 'TB', 1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'AWS', 'us-east-1', 'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT', 'AWS', 'us-east-1', 'TB_MONTH', 0.10, 'CREDITS'),
    ('DATA_TRANSFER', 'AWS', 'us-west-2', 'TB', 2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS', 'us-west-2', 'TB', 1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'AWS', 'us-west-2', 'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT', 'AWS', 'us-west-2', 'TB_MONTH', 0.10, 'CREDITS'),
    ('DATA_TRANSFER', 'AWS', 'eu-west-1', 'TB', 2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS', 'eu-west-1', 'TB', 1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'AWS', 'eu-west-1', 'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT', 'AWS', 'eu-west-1', 'TB_MONTH', 0.10, 'CREDITS'),
    ('DATA_TRANSFER', 'AWS', 'ap-southeast-1', 'TB', 2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS', 'ap-southeast-1', 'TB', 1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'AWS', 'ap-southeast-1', 'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT', 'AWS', 'ap-southeast-1', 'TB_MONTH', 0.10, 'CREDITS'),
    -- Azure Regions
    ('DATA_TRANSFER', 'AZURE', 'eastus2', 'TB', 2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'eastus2', 'TB', 1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'AZURE', 'eastus2', 'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT', 'AZURE', 'eastus2', 'TB_MONTH', 0.12, 'CREDITS'),
    ('DATA_TRANSFER', 'AZURE', 'westus2', 'TB', 2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'westus2', 'TB', 1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'AZURE', 'westus2', 'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT', 'AZURE', 'westus2', 'TB_MONTH', 0.12, 'CREDITS'),
    ('DATA_TRANSFER', 'AZURE', 'westeurope', 'TB', 2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'westeurope', 'TB', 1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'AZURE', 'westeurope', 'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT', 'AZURE', 'westeurope', 'TB_MONTH', 0.12, 'CREDITS'),
    ('DATA_TRANSFER', 'AZURE', 'southeastasia', 'TB', 2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'southeastasia', 'TB', 1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'AZURE', 'southeastasia', 'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT', 'AZURE', 'southeastasia', 'TB_MONTH', 0.12, 'CREDITS'),
    -- GCP Regions
    ('DATA_TRANSFER', 'GCP', 'us-central1', 'TB', 2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP', 'us-central1', 'TB', 1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'GCP', 'us-central1', 'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT', 'GCP', 'us-central1', 'TB_MONTH', 0.11, 'CREDITS'),
    ('DATA_TRANSFER', 'GCP', 'us-west1', 'TB', 2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP', 'us-west1', 'TB', 1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'GCP', 'us-west1', 'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT', 'GCP', 'us-west1', 'TB_MONTH', 0.11, 'CREDITS'),
    ('DATA_TRANSFER', 'GCP', 'europe-west1', 'TB', 2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP', 'europe-west1', 'TB', 1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'GCP', 'europe-west1', 'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT', 'GCP', 'europe-west1', 'TB_MONTH', 0.11, 'CREDITS'),
    ('DATA_TRANSFER', 'GCP', 'asia-southeast1', 'TB', 2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP', 'asia-southeast1', 'TB', 1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH', 'GCP', 'asia-southeast1', 'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT', 'GCP', 'asia-southeast1', 'TB_MONTH', 0.11, 'CREDITS');

/*****************************************************************************
 * SECTION 6: Grants (Demo Access)
 *****************************************************************************/

-- Grant minimal ACCOUNT_USAGE access for DB_METADATA view (prefer DB roles over IMPORTED PRIVILEGES)
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.USAGE_VIEWER TO ROLE SYSADMIN;

-- Grant demo object access to PUBLIC (as SYSADMIN, the owner)
USE ROLE SYSADMIN;
GRANT USAGE ON WAREHOUSE SFE_REPLICATION_CALC_WH TO ROLE PUBLIC;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.REPLICATION_CALC TO ROLE PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.REPLICATION_CALC
    TO ROLE PUBLIC;
GRANT SELECT ON ALL VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.REPLICATION_CALC
    TO ROLE PUBLIC;
GRANT USAGE ON STREAMLIT REPLICATION_CALCULATOR TO ROLE PUBLIC;

/*****************************************************************************
 * SECTION 7: Status
 *****************************************************************************/
SHOW STREAMLITS LIKE 'REPLICATION_CALCULATOR' IN SCHEMA SNOWFLAKE_EXAMPLE.REPLICATION_CALC;
SELECT COUNT(*) AS PRICING_RATES_LOADED
FROM SNOWFLAKE_EXAMPLE.REPLICATION_CALC.PRICING_CURRENT;
