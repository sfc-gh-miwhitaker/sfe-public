/*==============================================================================
  PII Auto-Classification Walkthrough | Pair-programmed by SE Community + Cortex Code
  Expires: 2027-01-04

  INSTRUCTIONS:
    Open Snowsight -> New Worksheet -> Paste this file -> Run All.
    Runtime: about 2 minutes. No values to edit.

  WHAT GETS CREATED:
    Roles       PII_CLASSIFICATION_ADMIN (runs the setup), PII_ANALYST (sees masked data)
    Warehouse   SFE_PII_CLASSIFICATION_WH (XSMALL, 60s auto-suspend)
    Schemas     SNOWFLAKE_EXAMPLE.PII_GOVERNANCE  (tag, masking policy, classifier, profile)
                SNOWFLAKE_EXAMPLE.PII_DATA        (sample table; classification profile set here)
    Table       PII_DATA.CUSTOMERS  (200 rows of synthetic data, no real people)
    Tag         PII_GOVERNANCE.PII_SENSITIVITY
    Policy      PII_GOVERNANCE.MASK_PII_STRING (tag-based masking)
    Classifier  PII_GOVERNANCE.EMPLOYEE_IDS (custom regex category EMPLOYEE_ID)
    Profile     PII_GOVERNANCE.PII_PROFILE (auto_tag, tag map, custom classifier, exclusions)

  AFTER DEPLOY:
    1. Read the last two result grids: tags applied per column, then masked rows as PII_ANALYST.
    2. Open Governance & security -> Trust Center -> Data Security to see the same results.
    3. Scheduled classification of PII_DATA starts about one hour after this script runs.
    4. Clean up with sql/teardown.sql.

  PREREQUISITES:
    Enterprise Edition or higher. ACCOUNTADMIN for the first block only (role and grants).
==============================================================================*/

SELECT
    '2027-01-04'::DATE AS expiration_date,
    CURRENT_DATE()     AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2027-01-04'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2027-01-04'::DATE) < 0  THEN 'EXPIRED - Code may use outdated syntax. Check the guide for a newer version.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2027-01-04'::DATE) <= 7 THEN 'EXPIRING SOON - Verify syntax against current documentation.'
        ELSE 'ACTIVE - Safe to run.'
    END AS guide_status;

------------------------------------------------------------------------------
-- 1. One-time administrator setup (ACCOUNTADMIN)
------------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

SET me = CURRENT_USER();

CREATE ROLE IF NOT EXISTS PII_CLASSIFICATION_ADMIN
    COMMENT = 'Sets up sensitive data classification and tag-based masking';
CREATE ROLE IF NOT EXISTS PII_ANALYST
    COMMENT = 'Reads classified data; sees PII masked';
GRANT ROLE PII_CLASSIFICATION_ADMIN TO ROLE SYSADMIN;
GRANT ROLE PII_ANALYST TO ROLE SYSADMIN;
GRANT ROLE PII_CLASSIFICATION_ADMIN TO USER IDENTIFIER($me);
GRANT ROLE PII_ANALYST TO USER IDENTIFIER($me);

-- Create classification profiles and custom classifiers
GRANT DATABASE ROLE SNOWFLAKE.CLASSIFICATION_ADMIN TO ROLE PII_CLASSIFICATION_ADMIN;
-- Set the system and mapped tags on columns, and attach masking policies to tags
GRANT APPLY TAG ON ACCOUNT TO ROLE PII_CLASSIFICATION_ADMIN;
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE PII_CLASSIFICATION_ADMIN;
-- Use the Trust Center UI for the same setup and review
GRANT APPLICATION ROLE SNOWFLAKE.TRUST_CENTER_ADMIN TO ROLE PII_CLASSIFICATION_ADMIN;
-- Read DATA_CLASSIFICATION_LATEST and TAG_REFERENCES
GRANT DATABASE ROLE SNOWFLAKE.GOVERNANCE_VIEWER TO ROLE PII_CLASSIFICATION_ADMIN;

CREATE WAREHOUSE IF NOT EXISTS SFE_PII_CLASSIFICATION_WH
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 600
    COMMENT = 'PII auto-classification guide';
GRANT USAGE ON WAREHOUSE SFE_PII_CLASSIFICATION_WH TO ROLE PII_CLASSIFICATION_ADMIN;
GRANT USAGE ON WAREHOUSE SFE_PII_CLASSIFICATION_WH TO ROLE PII_ANALYST;

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE Community demos and guides';
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE PII_CLASSIFICATION_ADMIN;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE PII_ANALYST;
GRANT CREATE SCHEMA ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE PII_CLASSIFICATION_ADMIN;

------------------------------------------------------------------------------
-- 2. Governance objects and sample data (PII_CLASSIFICATION_ADMIN)
--    The role owns both schemas, which gives it EXECUTE AUTO CLASSIFICATION.
------------------------------------------------------------------------------
USE ROLE PII_CLASSIFICATION_ADMIN;
USE SECONDARY ROLES NONE;
USE WAREHOUSE SFE_PII_CLASSIFICATION_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.PII_GOVERNANCE
    COMMENT = 'Tags, masking policies, classifiers, and classification profiles';
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.PII_DATA
    COMMENT = 'Data monitored by sensitive data classification';
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.PII_DATA TO ROLE PII_ANALYST;

-- Synthetic customers: example.com emails, 555 phone numbers, invented names.
CREATE OR REPLACE TABLE SNOWFLAKE_EXAMPLE.PII_DATA.CUSTOMERS (
    customer_key   NUMBER(38,0),
    first_name     VARCHAR,
    last_name      VARCHAR,
    email          VARCHAR,
    phone_number   VARCHAR,
    street_address VARCHAR,
    employee_id    VARCHAR,
    loyalty_tier   VARCHAR
) COMMENT = 'Synthetic sample data for the PII auto-classification guide';

INSERT INTO SNOWFLAKE_EXAMPLE.PII_DATA.CUSTOMERS
WITH seq AS (
    SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 200))
),
names AS (
    SELECT
        n,
        ARRAY_CONSTRUCT('Olivia','Liam','Emma','Noah','Ava','Mateo','Sophia','Lucas','Mia','Ethan',
                        'Amelia','James','Harper','Benjamin','Evelyn','Henry','Aria','Daniel','Chloe','Samuel')[MOD(n, 20)]::VARCHAR AS fn,
        ARRAY_CONSTRUCT('Garcia','Smith','Nguyen','Johnson','Patel','Brown','Kim','Lopez','Wilson','Martin',
                        'Clark','Lewis','Walker','Young','Allen','King','Wright','Scott','Hill','Green')[MOD(n * 7, 20)]::VARCHAR AS ln
    FROM seq
)
SELECT
    1000 + n,
    fn,
    ln,
    LOWER(fn) || '.' || LOWER(ln) || n || '@example.com',
    '(555) ' || LPAD(MOD(n * 37, 900) + 100, 3, '0') || '-' || LPAD(MOD(n * 53, 10000), 4, '0'),
    (100 + MOD(n * 13, 9800)) || ' '
        || ARRAY_CONSTRUCT('Main St','Oak Ave','Pine Rd','Maple Dr','Cedar Ln','Elm St','Lake Blvd','Hill Ct')[MOD(n, 8)]::VARCHAR,
    'EMP-' || LPAD(100000 + n * 17, 6, '0'),
    ARRAY_CONSTRUCT('BRONZE','SILVER','GOLD','PLATINUM')[MOD(n, 4)]::VARCHAR
FROM names;

GRANT SELECT ON TABLE SNOWFLAKE_EXAMPLE.PII_DATA.CUSTOMERS TO ROLE PII_ANALYST;

-- Your own sensitivity tag. Classification maps its findings onto these values.
CREATE TAG IF NOT EXISTS SNOWFLAKE_EXAMPLE.PII_GOVERNANCE.PII_SENSITIVITY
    ALLOWED_VALUES 'HIGHLY_CONFIDENTIAL', 'CONFIDENTIAL'
    COMMENT = 'Company sensitivity level, set automatically by classification';

-- Tag-based masking: any string column that receives the tag is masked for
-- every role except the governance admin.
CREATE MASKING POLICY IF NOT EXISTS SNOWFLAKE_EXAMPLE.PII_GOVERNANCE.MASK_PII_STRING
    AS (val STRING) RETURNS STRING ->
    CASE
        WHEN IS_ROLE_IN_SESSION('PII_CLASSIFICATION_ADMIN') THEN val
        ELSE '***MASKED***'
    END
    COMMENT = 'Masks string columns tagged PII_SENSITIVITY';

ALTER TAG SNOWFLAKE_EXAMPLE.PII_GOVERNANCE.PII_SENSITIVITY
    SET MASKING POLICY SNOWFLAKE_EXAMPLE.PII_GOVERNANCE.MASK_PII_STRING FORCE;

------------------------------------------------------------------------------
-- 3. Custom classifier for an identifier Snowflake does not know
------------------------------------------------------------------------------
USE SCHEMA SNOWFLAKE_EXAMPLE.PII_GOVERNANCE;

-- Prove the regex before you trust it (expect 200).
SELECT COUNT(*) AS matching_employee_ids
FROM SNOWFLAKE_EXAMPLE.PII_DATA.CUSTOMERS
WHERE employee_id REGEXP '^EMP-[0-9]{6}$';

CREATE OR REPLACE SNOWFLAKE.DATA_PRIVACY.CUSTOM_CLASSIFIER EMPLOYEE_IDS();

CALL EMPLOYEE_IDS!ADD_REGEX(
    SEMANTIC_CATEGORY => 'EMPLOYEE_ID',
    PRIVACY_CATEGORY  => 'IDENTIFIER',
    VALUE_REGEX       => '^EMP-[0-9]{6}$',
    COL_NAME_REGEX    => '.*EMP.*ID.*',
    DESCRIPTION       => 'Internal employee identifier, format EMP-######',
    THRESHOLD         => 0.8
);

------------------------------------------------------------------------------
-- 4. Classification profile
--    Autopilot scheduling is the default because no schedule keys are set.
--    Tag map order matters: the first matching entry wins.
------------------------------------------------------------------------------
-- A profile that is set on a schema or database cannot be replaced
-- (error 398036). Detach it first so this script can be re-run.
ALTER SCHEMA SNOWFLAKE_EXAMPLE.PII_DATA UNSET CLASSIFICATION_PROFILE;

CREATE OR REPLACE SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE PII_PROFILE({
    'auto_tag': true,
    'classify_views': false,
    'enable_tag_based_sensitive_data_exclusion': true,
    'tag_map': {
        'column_tag_map': [
            {
                'tag_name': 'SNOWFLAKE_EXAMPLE.PII_GOVERNANCE.PII_SENSITIVITY',
                'tag_value': 'HIGHLY_CONFIDENTIAL',
                'semantic_categories': ['NAME', 'NATIONAL_IDENTIFIER', 'EMPLOYEE_ID']
            },
            {
                'tag_name': 'SNOWFLAKE_EXAMPLE.PII_GOVERNANCE.PII_SENSITIVITY',
                'tag_value': 'CONFIDENTIAL',
                'semantic_categories': ['EMAIL', 'PHONE_NUMBER', 'STREET_ADDRESS']
            }
        ]
    }
});

CALL PII_PROFILE!SET_CUSTOM_CLASSIFIERS({'EMPLOYEE_IDS': EMPLOYEE_IDS!LIST()});

SELECT PII_PROFILE!DESCRIBE() AS profile_configuration;

------------------------------------------------------------------------------
-- 5. Classify now with the profile, then turn on scheduled classification
------------------------------------------------------------------------------
-- Runs immediately and applies tags because the profile has auto_tag = true.
CALL SYSTEM$CLASSIFY(
    'SNOWFLAKE_EXAMPLE.PII_DATA.CUSTOMERS',
    'SNOWFLAKE_EXAMPLE.PII_GOVERNANCE.PII_PROFILE'
);

-- Every new or changed table in PII_DATA is now classified automatically.
ALTER SCHEMA SNOWFLAKE_EXAMPLE.PII_DATA
    SET CLASSIFICATION_PROFILE = 'SNOWFLAKE_EXAMPLE.PII_GOVERNANCE.PII_PROFILE';

------------------------------------------------------------------------------
-- 6. Verify
------------------------------------------------------------------------------
-- Tags applied to each column (immediate; ACCOUNT_USAGE views lag by hours).
SELECT
    column_name,
    LOWER(tag_database || '.' || tag_schema || '.' || tag_name) AS tag,
    tag_value
FROM TABLE(SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'SNOWFLAKE_EXAMPLE.PII_DATA.CUSTOMERS', 'TABLE'))
ORDER BY column_name, tag;

-- The same rows as an analyst: tagged columns are masked, the rest are not.
USE ROLE PII_ANALYST;
USE SECONDARY ROLES NONE;
USE WAREHOUSE SFE_PII_CLASSIFICATION_WH;

SELECT customer_key, first_name, last_name, email, phone_number, street_address, employee_id, loyalty_tier
FROM SNOWFLAKE_EXAMPLE.PII_DATA.CUSTOMERS
ORDER BY customer_key
LIMIT 5;
