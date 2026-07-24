/*==============================================================================
TEARDOWN - Cortex AI Cost Controls (demo)
WARNING: This will DELETE all project objects. Cannot be undone.
==============================================================================*/

USE ROLE SYSADMIN;

-- Drop the schema (cascades views, tables, procedures, tasks, tag, streamlit, budget)
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS CASCADE;
DROP WAREHOUSE IF EXISTS SFE_CORTEX_AI_COST_CONTROLS_WH;

-- Note: the IMPORTED PRIVILEGES grant to SYSADMIN is left in place — it is
-- account-wide and other projects may rely on it. Revoke manually if required:
-- USE ROLE ACCOUNTADMIN;
-- REVOKE IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE FROM ROLE SYSADMIN;

-- PROTECTED - NEVER DROP:
-- SNOWFLAKE_EXAMPLE database
-- SNOWFLAKE_EXAMPLE.GIT_REPOS schema
-- SFE_GIT_API_INTEGRATION

SELECT 'Teardown complete!' AS status;
