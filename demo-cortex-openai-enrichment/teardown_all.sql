/*==============================================================================
TEARDOWN ALL - OpenAI Data Engineering
WARNING: This will DELETE all demo objects. Cannot be undone.
==============================================================================*/

USE ROLE SYSADMIN;

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG CASCADE;

DROP WAREHOUSE IF EXISTS SFE_OPENAI_DATA_ENG_WH;

-- PROTECTED - NEVER DROP:
-- SNOWFLAKE_EXAMPLE database
-- SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS schema
-- SFE_GIT_API_INTEGRATION

SELECT 'Teardown complete!' AS status;
