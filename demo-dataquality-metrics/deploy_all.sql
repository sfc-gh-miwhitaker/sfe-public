/*******************************************************************************
 * DEMO METADATA (Machine-readable - Do not modify format)
 * PROJECT_NAME: Data Quality Metrics & Reporting Demo
 * AUTHOR: SE Community
 * CREATED: 2026-01-15
 * EXPIRES: 2026-02-14
 * GITHUB_REPO: https://github.com/sfc-gh-miwhitaker/sfe-public
 * PURPOSE: Reference implementation for automated data quality monitoring and reporting using Snowflake native features.
 *
 * DEPLOYMENT INSTRUCTIONS:
 * 1. Open Snowsight (https://app.snowflake.com)
 * 2. Copy this ENTIRE script
 * 3. Paste into a new SQL worksheet
 * 4. Click "Run All" (or press Cmd/Ctrl + Enter repeatedly)
 * 5. Monitor output for any errors
 *
 * This script creates all necessary Snowflake objects by pulling SQL files
 * from the GitHub repository using native Git integration.
 *
 * To extend expiration: Update the EXPIRES metadata and README date fields
 ******************************************************************************/
-- ============================================================================
-- Script: deploy_all.sql
-- Purpose: Deploy the full Data Quality Metrics demo from Git in Snowsight.
-- Target: SNOWFLAKE_EXAMPLE database, DATA_QUALITY schema, SFE_DATA_QUALITY_WH.
-- Deps: GitHub repo accessible; privileges to create DB/schema/warehouse.
-- ============================================================================

/*******************************************************************************
 * SECTION 0: Warehouse Setup (MUST BE FIRST - all operations need compute)
 ******************************************************************************/

-- Create warehouse first (this command itself doesn't need a warehouse)
CREATE WAREHOUSE IF NOT EXISTS SFE_DATA_QUALITY_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'DEMO: Data Quality Metrics & Reporting Demo - Dedicated compute for demo workloads | Author: SE Community | Expires: 2026-02-14';

-- Set warehouse context IMMEDIATELY (all subsequent commands need compute)
USE WAREHOUSE SFE_DATA_QUALITY_WH;

/*******************************************************************************
 * SECTION 1: Expiration Check
 ******************************************************************************/
-- This demo expires 30 days after creation.
-- Expiration date: 2026-02-14

EXECUTE IMMEDIATE
$$
DECLARE
    v_expiration_date DATE := '2026-02-14';
    demo_expired EXCEPTION (-20001, 'DEMO EXPIRED: This project expired. Please contact the SE team for an updated version.');
BEGIN
    IF (CURRENT_DATE() > v_expiration_date) THEN
        RAISE demo_expired;
    END IF;
END;
$$;

/*******************************************************************************
 * SECTION 2: Database Setup
 ******************************************************************************/

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Data Quality Metrics & Reporting Demo | Author: SE Community | Expires: 2026-02-14';

USE DATABASE SNOWFLAKE_EXAMPLE;

/*******************************************************************************
 * SECTION 2: Git Integration Setup
 ******************************************************************************/

-- Create API Integration for GitHub access (public repos, no authentication)
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

-- Create schema for Git repository
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'DEMO: Data Quality Metrics & Reporting Demo - Git repositories and deployment objects | Author: SE Community | Expires: 2026-02-14';

-- Create Git Repository stage (requires warehouse for initial fetch)
CREATE OR REPLACE GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'DEMO: Data Quality Metrics & Reporting Demo - Source repository for deployment scripts | Author: SE Community | Expires: 2026-02-14';

/*******************************************************************************
 * SECTION 3: Execute Deployment Scripts from Git
 *
 * Pattern: EXECUTE IMMEDIATE FROM @database.schema.git_repo/branches/main/path/to/file.sql
 ******************************************************************************/

EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/demo-dataquality-metrics/sql/01_setup/01_create_database.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/demo-dataquality-metrics/sql/01_setup/02_create_schemas.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/demo-dataquality-metrics/sql/02_data/01_create_tables.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/demo-dataquality-metrics/sql/02_data/02_load_sample_data.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/demo-dataquality-metrics/sql/03_transformations/01_create_streams.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/demo-dataquality-metrics/sql/03_transformations/02_create_views.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/demo-dataquality-metrics/sql/03_transformations/03_create_tasks.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/demo-dataquality-metrics/sql/04_streamlit/01_create_dashboard.sql;

/*******************************************************************************
 * DEPLOYMENT COMPLETE
 *******************************************************************************
-- =============================================================================
-- VERIFICATION QUERIES (Run individually AFTER deployment completes)
-- =============================================================================
/*
SHOW DATABASES LIKE 'SNOWFLAKE_EXAMPLE%';
SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;
SHOW GIT BRANCHES IN SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO;
SHOW TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.DATA_QUALITY;
SHOW STREAMS IN SCHEMA SNOWFLAKE_EXAMPLE.DATA_QUALITY;
SHOW TASKS IN SCHEMA SNOWFLAKE_EXAMPLE.DATA_QUALITY;
SHOW STREAMLITS;
*/

/*******************************************************************************
 * TROUBLESHOOTING
 ******************************************************************************/

-- If you encounter errors:
-- 1. Check that you have ACCOUNTADMIN role or appropriate grants
-- 2. Verify the GitHub repository is accessible: https://github.com/sfc-gh-miwhitaker/sfe-public
-- 3. Review error messages in the output pane
-- 4. Check README.md for additional troubleshooting steps
--
-- To clean up all objects created by this demo:
-- Run: @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/demo-dataquality-metrics/sql/99_cleanup/teardown_all.sql
