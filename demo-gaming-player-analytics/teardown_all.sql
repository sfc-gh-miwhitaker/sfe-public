/*==============================================================================
TEARDOWN - Gaming Player Analytics
WARNING: This will DELETE all project objects. Cannot be undone.
==============================================================================*/

USE ROLE SYSADMIN;

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS CASCADE;
DROP WAREHOUSE IF EXISTS SFE_GAMING_PLAYER_ANALYTICS_WH;
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_GAMING_PLAYER_ANALYTICS;

-- PROTECTED - NEVER DROP:
-- SNOWFLAKE_EXAMPLE database
-- SNOWFLAKE_EXAMPLE.GIT_REPOS schema
-- SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS schema
-- SFE_GIT_API_INTEGRATION

SELECT 'Teardown complete!' AS status;
