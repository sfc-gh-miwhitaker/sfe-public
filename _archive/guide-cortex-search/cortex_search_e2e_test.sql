-- ============================================================================
-- CORTEX SEARCH SERVICE - END-TO-END TEST
-- Using SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.COMPANY_EVENT_TRANSCRIPT_ATTRIBUTES
-- ============================================================================
-- This script demonstrates:
--   1. Creating a Cortex Search service from sample data
--   2. Testing the service with SEARCH_PREVIEW
--   3. Exporting the service specification
--   4. Recreating the service from the exported spec
-- ============================================================================

-- ============================================================================
-- SETUP: Configure your environment (Least Privilege)
-- ============================================================================

-- Option 1: Use SYSADMIN for initial setup (one-time)
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.CORTEX_SEARCH;

-- Option 2: Create a dedicated role for Cortex Search (recommended)
-- Run this section once as SECURITYADMIN/ACCOUNTADMIN, then use CORTEX_SEARCH_ADMIN going forward
/*
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS CORTEX_SEARCH_ADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE CORTEX_SEARCH_ADMIN;

GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE CORTEX_SEARCH_ADMIN;
GRANT USAGE, CREATE TABLE, CREATE CORTEX SEARCH SERVICE ON SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_SEARCH TO ROLE CORTEX_SEARCH_ADMIN;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE CORTEX_SEARCH_ADMIN;

-- Grant access to source data
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_PUBLIC_DATA_FREE TO ROLE CORTEX_SEARCH_ADMIN;

GRANT ROLE CORTEX_SEARCH_ADMIN TO USER <your_user>;
*/

-- Switch to least-privilege role for remaining operations
USE ROLE SYSADMIN;  -- Or CORTEX_SEARCH_ADMIN if created above
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA CORTEX_SEARCH;

-- ============================================================================
-- STEP 1: Create a materialized source table from the sample data
-- ============================================================================
-- Note: Cortex Search needs a table/view it can access. We'll create a
-- simplified table with the key searchable fields.

CREATE OR REPLACE TABLE SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.COMPANY_TRANSCRIPTS AS
SELECT
    COMPANY_ID,
    CIK,
    COMPANY_NAME,
    PRIMARY_TICKER,
    FISCAL_YEAR,
    EVENT_TYPE,
    TRANSCRIPT_TYPE,
    TRANSCRIPT:paragraphs[0]:text::STRING AS TRANSCRIPT_EXCERPT,
    LEFT(TRANSCRIPT::STRING, 50000) AS TRANSCRIPT_FULL,
    EVENT_TIMESTAMP
FROM SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.COMPANY_EVENT_TRANSCRIPT_ATTRIBUTES
WHERE TRANSCRIPT IS NOT NULL
  AND TRANSCRIPT:paragraphs[0]:text IS NOT NULL
LIMIT 5000;  -- Limit for testing (adjust as needed)

-- Verify the table
SELECT COUNT(*) AS row_count FROM SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.COMPANY_TRANSCRIPTS;
SELECT * FROM SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.COMPANY_TRANSCRIPTS LIMIT 3;

-- ============================================================================
-- STEP 2: Create the Cortex Search Service
-- ============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V1
  ON TRANSCRIPT_EXCERPT
  ATTRIBUTES COMPANY_NAME, PRIMARY_TICKER, EVENT_TYPE, FISCAL_YEAR
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT
    COMPANY_ID,
    COMPANY_NAME,
    PRIMARY_TICKER,
    EVENT_TYPE,
    FISCAL_YEAR,
    TRANSCRIPT_EXCERPT,
    EVENT_TIMESTAMP
  FROM SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.COMPANY_TRANSCRIPTS
  WHERE TRANSCRIPT_EXCERPT IS NOT NULL
);

-- Wait for indexing to complete (check status)
SHOW CORTEX SEARCH SERVICES IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_SEARCH;

-- ============================================================================
-- STEP 3: Test the service with SEARCH_PREVIEW
-- ============================================================================

-- Basic search
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V1',
    '{
      "query": "revenue growth quarterly earnings",
      "columns": ["COMPANY_NAME", "PRIMARY_TICKER", "TRANSCRIPT_EXCERPT"],
      "limit": 5
    }'
  )
)['results'] AS results;

-- Search with filter by event type
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V1',
    '{
      "query": "streaming subscribers growth",
      "columns": ["COMPANY_NAME", "PRIMARY_TICKER", "EVENT_TYPE", "TRANSCRIPT_EXCERPT"],
      "filter": {"@eq": {"EVENT_TYPE": "Earnings Call"}},
      "limit": 5
    }'
  )
)['results'] AS results;

-- Search with company filter
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V1',
    '{
      "query": "market expansion strategy",
      "columns": ["COMPANY_NAME", "EVENT_TYPE", "TRANSCRIPT_EXCERPT"],
      "filter": {"@eq": {"COMPANY_NAME": "WARNER BROS. DISCOVERY, INC."}},
      "limit": 3
    }'
  )
)['results'] AS results;

-- Flatten results into rows for easier analysis
SELECT
  r.value:COMPANY_NAME::STRING AS company,
  r.value:PRIMARY_TICKER::STRING AS ticker,
  r.value:TRANSCRIPT_EXCERPT::STRING AS excerpt
FROM (
  SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
      'SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V1',
      '{"query": "artificial intelligence AI investment", "columns": ["COMPANY_NAME", "PRIMARY_TICKER", "TRANSCRIPT_EXCERPT"], "limit": 5}'
    )
  )['results'] AS results
), LATERAL FLATTEN(input => results) r;

-- ============================================================================
-- STEP 4: Export the service specification
-- ============================================================================

-- Get full service details
DESCRIBE CORTEX SEARCH SERVICE SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V1;

-- Store the spec in a variable/table for recreation
CREATE OR REPLACE TABLE SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.SERVICE_SPEC AS
SELECT
  name AS service_name,
  database_name,
  schema_name,
  search_column,
  attribute_columns,
  warehouse,
  target_lag,
  definition AS source_query,
  embedding_model
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- View the exported spec
SELECT * FROM SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.SERVICE_SPEC;

-- Generate the CREATE statement
SELECT
  'CREATE OR REPLACE CORTEX SEARCH SERVICE ' || database_name || '.' || schema_name || '.' || service_name || '_V2' || CHR(10) ||
  '  ON ' || search_column || CHR(10) ||
  '  ATTRIBUTES ' || attribute_columns || CHR(10) ||
  '  WAREHOUSE = ' || warehouse || CHR(10) ||
  '  TARGET_LAG = ''' || target_lag || '''' || CHR(10) ||
  'AS (' || CHR(10) ||
  '  ' || source_query || CHR(10) ||
  ');' AS create_statement
FROM SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.SERVICE_SPEC;

-- ============================================================================
-- STEP 5: Recreate the service from the exported spec (V2)
-- ============================================================================

-- This demonstrates deploying from an exported definition
-- In practice, you'd parameterize database/schema/warehouse for different environments

CREATE OR REPLACE CORTEX SEARCH SERVICE SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V2
  ON TRANSCRIPT_EXCERPT
  ATTRIBUTES COMPANY_NAME, PRIMARY_TICKER, EVENT_TYPE, FISCAL_YEAR
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT
    COMPANY_ID,
    COMPANY_NAME,
    PRIMARY_TICKER,
    EVENT_TYPE,
    FISCAL_YEAR,
    TRANSCRIPT_EXCERPT,
    EVENT_TIMESTAMP
  FROM SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.COMPANY_TRANSCRIPTS
  WHERE TRANSCRIPT_EXCERPT IS NOT NULL
);

-- ============================================================================
-- STEP 6: Verify both services work identically
-- ============================================================================

-- Compare V1 results
SELECT 'V1' AS version, PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V1',
    '{"query": "digital transformation cloud", "columns": ["COMPANY_NAME", "TRANSCRIPT_EXCERPT"], "limit": 3}'
  )
)['results'] AS results;

-- Compare V2 results
SELECT 'V2' AS version, PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V2',
    '{"query": "digital transformation cloud", "columns": ["COMPANY_NAME", "TRANSCRIPT_EXCERPT"], "limit": 3}'
  )
)['results'] AS results;

-- List both services
SHOW CORTEX SEARCH SERVICES IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_SEARCH;

-- ============================================================================
-- STEP 7: Parameterized deployment template
-- ============================================================================
-- Use this template with Snowflake CLI for cross-environment deployment:
--
-- snow sql -f deploy_transcript_search.sql \
--   -D target_database=PROD_DB \
--   -D target_schema=SEARCH_SERVICES \
--   -D source_database=PROD_DB \
--   -D source_schema=DATA \
--   -D warehouse=PROD_WH \
--   -D target_lag='1 hour'
--
-- Template content:
/*
CREATE OR REPLACE CORTEX SEARCH SERVICE &{target_database}.&{target_schema}.TRANSCRIPT_SEARCH
  ON TRANSCRIPT_EXCERPT
  ATTRIBUTES COMPANY_NAME, PRIMARY_TICKER, EVENT_TYPE, FISCAL_YEAR
  WAREHOUSE = &{warehouse}
  TARGET_LAG = '&{target_lag}'
AS (
  SELECT
    COMPANY_ID,
    COMPANY_NAME,
    PRIMARY_TICKER,
    EVENT_TYPE,
    FISCAL_YEAR,
    TRANSCRIPT_EXCERPT,
    EVENT_TIMESTAMP
  FROM &{source_database}.&{source_schema}.COMPANY_TRANSCRIPTS
  WHERE TRANSCRIPT_EXCERPT IS NOT NULL
);

GRANT USAGE ON CORTEX SEARCH SERVICE &{target_database}.&{target_schema}.TRANSCRIPT_SEARCH
  TO ROLE &{app_role};
*/

-- ============================================================================
-- CLEANUP (Optional)
-- ============================================================================
-- Uncomment to clean up test resources

-- DROP CORTEX SEARCH SERVICE IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V1;
-- DROP CORTEX SEARCH SERVICE IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.TRANSCRIPT_SEARCH_V2;
-- DROP TABLE IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.COMPANY_TRANSCRIPTS;
-- DROP TABLE IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_SEARCH.SERVICE_SPEC;
-- DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.CORTEX_SEARCH;

-- ============================================================================
-- END OF TEST SCRIPT
-- ============================================================================
