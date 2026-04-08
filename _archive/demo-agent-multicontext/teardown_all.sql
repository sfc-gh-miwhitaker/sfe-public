/*==============================================================================
TEARDOWN ALL - Agent Multicontext Demo
WARNING: This will DELETE all demo objects. Cannot be undone.
==============================================================================*/

-- Drop row access policies first (must be removed before dropping tables)
ALTER TABLE SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT.VIEWERSHIP_METRICS
  DROP ROW ACCESS POLICY IF EXISTS station_viewership_policy;

ALTER TABLE SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT.MEMBER_ACCOUNTS
  DROP ROW ACCESS POLICY IF EXISTS station_member_policy;

-- Drop project schema (CASCADE removes all objects including Cortex Search service)
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT CASCADE;

-- Drop project warehouse
DROP WAREHOUSE IF EXISTS SFE_AGENT_MULTICONTEXT_WH;

-- Drop semantic view
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AGENT_MULTICONTEXT_VIEWERSHIP;

-- Drop Git repository for this demo (keep GIT_REPOS schema)
DROP GIT REPOSITORY IF EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_AGENT_MULTICONTEXT_REPO;

-- Drop roles
DROP ROLE IF EXISTS TV_VIEWER_ROLE;
DROP ROLE IF EXISTS TV_ADMIN_ROLE;

-- PROTECTED - NEVER DROP:
-- SNOWFLAKE_EXAMPLE database
-- SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS schema
-- SNOWFLAKE_EXAMPLE.GIT_REPOS schema
-- SFE_GIT_API_INTEGRATION

SELECT 'Teardown complete!' AS status;
