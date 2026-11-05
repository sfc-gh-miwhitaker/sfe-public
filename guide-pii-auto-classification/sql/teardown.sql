/*==============================================================================
  PII Auto-Classification Teardown | Pair-programmed by SE Community + Cortex Code

  INSTRUCTIONS: Open Snowsight -> New Worksheet -> Paste -> Run All.
  Removes only what sql/walkthrough.sql created. Keeps the shared
  SNOWFLAKE_EXAMPLE database and its other schemas.
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-- Stop scheduled classification before dropping the profile.
ALTER SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.PII_DATA UNSET CLASSIFICATION_PROFILE;

-- The masking policy cannot be dropped while it is attached to the tag.
ALTER TAG IF EXISTS SNOWFLAKE_EXAMPLE.PII_GOVERNANCE.PII_SENSITIVITY
    UNSET MASKING POLICY SNOWFLAKE_EXAMPLE.PII_GOVERNANCE.MASK_PII_STRING;

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.PII_DATA;
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.PII_GOVERNANCE;

DROP WAREHOUSE IF EXISTS SFE_PII_CLASSIFICATION_WH;
DROP ROLE IF EXISTS PII_ANALYST;
DROP ROLE IF EXISTS PII_CLASSIFICATION_ADMIN;

SELECT 'PII auto-classification guide objects removed' AS status;
