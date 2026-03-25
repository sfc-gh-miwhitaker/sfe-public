/*==============================================================================
TEARDOWN - Music Label Marketing Analytics
WARNING: This will DELETE all demo objects. Cannot be undone.
==============================================================================*/

USE ROLE SYSADMIN;

-- Reverse dependency order: Streamlit → Agent → Semantic View → Task → Schema → Warehouse

-- Streamlit app
DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING.MUSIC_MARKETING_APP;

-- Agent (depends on semantic view)
DROP AGENT IF EXISTS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING.MUSIC_MARKETING_AGENT;

-- Semantic view (references objects in MUSIC_MARKETING schema — drop before schema CASCADE)
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MUSIC_MARKETING;

-- Task (suspend first)
ALTER TASK IF EXISTS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING.BUDGET_ALERT_TASK SUSPEND;

-- Schema cascade drops all tables, views, dynamic tables, tasks
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING CASCADE;

-- Warehouse
DROP WAREHOUSE IF EXISTS SFE_MUSIC_MARKETING_WH;

-- PROTECTED - NEVER DROP:
-- SNOWFLAKE_EXAMPLE database
-- SNOWFLAKE_EXAMPLE.GIT_REPOS schema
-- SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS schema
-- SFE_GIT_API_INTEGRATION

SELECT 'Teardown complete!' AS status;
