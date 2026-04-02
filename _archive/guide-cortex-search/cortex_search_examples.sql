-- ============================================================================
-- CORTEX SEARCH SERVICE - EXAMPLE COMMANDS & GUIDANCE
-- ============================================================================
-- This file provides SQL examples for creating, managing, and querying
-- Cortex Search services in Snowflake.
-- ============================================================================

-- ============================================================================
-- SECTION 1: PREREQUISITES
-- ============================================================================

-- Verify you have the CORTEX_USER database role
SHOW GRANTS TO USER CURRENT_USER();

-- Grant CORTEX_USER if needed (requires ACCOUNTADMIN)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE my_role;

-- Set context
USE ROLE my_role;
USE WAREHOUSE my_warehouse;
USE DATABASE my_database;
USE SCHEMA my_schema;

-- ============================================================================
-- SECTION 2: CREATE CORTEX SEARCH SERVICE
-- ============================================================================

-- Basic service creation
CREATE OR REPLACE CORTEX SEARCH SERVICE my_search_service
  ON search_text_column
  WAREHOUSE = my_warehouse
  TARGET_LAG = '1 hour'
AS (
  SELECT
    search_text_column
  FROM my_table
);

-- With filterable attributes
CREATE OR REPLACE CORTEX SEARCH SERVICE support_ticket_search
  ON ticket_description
  ATTRIBUTES category, priority, region, created_date
  WAREHOUSE = my_warehouse
  TARGET_LAG = '1 hour'
AS (
  SELECT
    ticket_id,
    ticket_description,
    category,
    priority,
    region,
    created_date
  FROM support_tickets
  WHERE status != 'DELETED'
);

-- With explicit embedding model
CREATE OR REPLACE CORTEX SEARCH SERVICE product_search
  ON product_description
  ATTRIBUTES brand, category, price_tier
  WAREHOUSE = my_warehouse
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
AS (
  SELECT
    product_id,
    product_name,
    product_description,
    brand,
    category,
    price_tier
  FROM products
  WHERE is_active = TRUE
);

-- With JOIN (complex source query)
CREATE OR REPLACE CORTEX SEARCH SERVICE knowledge_base_search
  ON article_content
  ATTRIBUTES department, author_name, publish_date
  WAREHOUSE = my_warehouse
  TARGET_LAG = '1 day'
AS (
  SELECT
    a.article_id,
    a.title,
    a.article_content,
    a.department,
    u.name AS author_name,
    a.publish_date
  FROM articles a
  JOIN users u ON a.author_id = u.user_id
  WHERE a.status = 'PUBLISHED'
);

-- ============================================================================
-- SECTION 3: DESCRIBE & EXPORT SERVICE DEFINITION
-- ============================================================================

-- Get full service details
DESCRIBE CORTEX SEARCH SERVICE my_search_service;

-- Get specific properties for deployment script
-- Note: DESCRIBE output columns are lowercase and require double-quoted identifiers
SELECT
  'CREATE OR REPLACE CORTEX SEARCH SERVICE ' ||
  "database_name" || '.' || "schema_name" || '.' || "name" ||
  ' ON ' || "search_column" ||
  CASE WHEN "attribute_columns" IS NOT NULL
    THEN ' ATTRIBUTES ' || "attribute_columns"
    ELSE ''
  END ||
  ' WAREHOUSE = ' || "warehouse" ||
  ' TARGET_LAG = ''' || "target_lag" || '''' ||
  CASE WHEN "embedding_model" IS NOT NULL
    THEN ' EMBEDDING_MODEL = ''' || "embedding_model" || ''''
    ELSE ''
  END ||
  ' AS (' || "definition" || ');' AS create_statement
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- ============================================================================
-- SECTION 4: LIST & MANAGE SERVICES
-- ============================================================================

-- List all Cortex Search services in current schema
SHOW CORTEX SEARCH SERVICES;

-- List services in specific schema
SHOW CORTEX SEARCH SERVICES IN SCHEMA my_database.my_schema;

-- List services in entire database
SHOW CORTEX SEARCH SERVICES IN DATABASE my_database;

-- Check service status
SELECT
  "name",
  "indexing_state",
  "serving_state",
  "source_data_num_rows",
  "data_timestamp"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- ============================================================================
-- SECTION 5: ALTER SERVICE
-- ============================================================================

-- Change target lag
ALTER CORTEX SEARCH SERVICE my_search_service
  SET TARGET_LAG = '30 minutes';

-- Change warehouse
ALTER CORTEX SEARCH SERVICE my_search_service
  SET WAREHOUSE = different_warehouse;

-- Suspend service (stops indexing and serving)
ALTER CORTEX SEARCH SERVICE my_search_service SUSPEND;

-- Resume service
ALTER CORTEX SEARCH SERVICE my_search_service RESUME;

-- ============================================================================
-- SECTION 6: QUERY WITH SEARCH_PREVIEW (Testing)
-- ============================================================================

-- Basic search
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'my_database.my_schema.my_search_service',
    '{
      "query": "search term here",
      "limit": 10
    }'
  )
)['results'] AS results;

-- With specific columns returned
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'my_database.my_schema.support_ticket_search',
    '{
      "query": "network connectivity issues",
      "columns": ["ticket_id", "ticket_description", "category", "priority"],
      "limit": 5
    }'
  )
)['results'] AS results;

-- With equality filter
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'my_database.my_schema.support_ticket_search',
    '{
      "query": "login problems",
      "columns": ["ticket_id", "ticket_description", "priority"],
      "filter": {"@eq": {"category": "Authentication"}},
      "limit": 10
    }'
  )
)['results'] AS results;

-- With multiple filters (AND)
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'my_database.my_schema.support_ticket_search',
    '{
      "query": "slow performance",
      "columns": ["ticket_id", "ticket_description"],
      "filter": {
        "@and": [
          {"@eq": {"region": "North America"}},
          {"@eq": {"priority": "High"}}
        ]
      },
      "limit": 10
    }'
  )
)['results'] AS results;

-- With OR filter
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'my_database.my_schema.product_search',
    '{
      "query": "wireless headphones",
      "columns": ["product_id", "product_name", "brand"],
      "filter": {
        "@or": [
          {"@eq": {"brand": "Sony"}},
          {"@eq": {"brand": "Bose"}}
        ]
      },
      "limit": 10
    }'
  )
)['results'] AS results;

-- With range filter (gte/lte)
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'my_database.my_schema.knowledge_base_search',
    '{
      "query": "security best practices",
      "columns": ["article_id", "title", "publish_date"],
      "filter": {"@gte": {"publish_date": "2024-01-01"}},
      "limit": 10
    }'
  )
)['results'] AS results;

-- With NOT filter
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'my_database.my_schema.support_ticket_search',
    '{
      "query": "password reset",
      "columns": ["ticket_id", "ticket_description", "priority"],
      "filter": {"@not": {"@eq": {"priority": "Low"}}},
      "limit": 10
    }'
  )
)['results'] AS results;

-- Flatten results into rows
SELECT
  r.value:ticket_id::STRING AS ticket_id,
  r.value:ticket_description::STRING AS description,
  r.value:priority::STRING AS priority
FROM (
  SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
      'my_database.my_schema.support_ticket_search',
      '{"query": "network issues", "columns": ["ticket_id", "ticket_description", "priority"], "limit": 5}'
    )
  )['results'] AS results
), LATERAL FLATTEN(input => results) r;

-- ============================================================================
-- SECTION 7: GRANTS & PERMISSIONS
-- ============================================================================

-- Grant usage to a role
GRANT USAGE ON CORTEX SEARCH SERVICE my_database.my_schema.my_search_service
  TO ROLE analyst_role;

-- Grant to multiple roles
GRANT USAGE ON CORTEX SEARCH SERVICE my_database.my_schema.my_search_service
  TO ROLE app_role, data_science_role;

-- Revoke usage
REVOKE USAGE ON CORTEX SEARCH SERVICE my_database.my_schema.my_search_service
  FROM ROLE analyst_role;

-- Show grants on service
SHOW GRANTS ON CORTEX SEARCH SERVICE my_database.my_schema.my_search_service;

-- ============================================================================
-- SECTION 8: DROP SERVICE
-- ============================================================================

-- Drop service
DROP CORTEX SEARCH SERVICE my_search_service;

-- Drop if exists (no error if missing)
DROP CORTEX SEARCH SERVICE IF EXISTS my_search_service;

-- ============================================================================
-- SECTION 9: PARAMETERIZED DEPLOYMENT TEMPLATE
-- ============================================================================

-- Use with: snow sql -f this_file.sql -D database=PROD_DB -D schema=PROD_SCHEMA ...

/*
CREATE OR REPLACE CORTEX SEARCH SERVICE &{database}.&{schema}.my_search_service
  ON search_column
  ATTRIBUTES attr1, attr2
  WAREHOUSE = &{warehouse}
  TARGET_LAG = '&{target_lag}'
AS (
  SELECT
    search_column,
    attr1,
    attr2
  FROM &{database}.&{schema}.source_table
);

GRANT USAGE ON CORTEX SEARCH SERVICE &{database}.&{schema}.my_search_service
  TO ROLE &{app_role};
*/

-- ============================================================================
-- SECTION 10: TROUBLESHOOTING
-- ============================================================================

-- Check indexing errors
SELECT
  "name",
  "indexing_state",
  "indexing_error"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-2)));  -- After SHOW CORTEX SEARCH SERVICES

-- Verify source data exists and has content
SELECT COUNT(*) FROM my_table WHERE search_text_column IS NOT NULL;

-- Check warehouse is running
SHOW WAREHOUSES LIKE 'my_warehouse';

-- Verify role permissions
SHOW GRANTS TO ROLE my_role;

-- ============================================================================
-- END OF FILE
-- ============================================================================
