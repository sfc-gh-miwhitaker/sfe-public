/*==============================================================================
DEPLOY ALL - Agent Multicontext Demo
Pair-programmed by SE Community + Cortex Code | Expires: 2026-07-06

TV network agent demo showing per-request context injection via the
Snowflake Agent Run API "without agent object" endpoint.

Demonstrates:
  - Dynamic instructions.system per request (user ID, station branding)
  - Three authorization tiers (Anonymous, Low Auth, Full Auth)
  - Cortex Search for knowledge base + Cortex Analyst for viewership data
  - Row Access Policies for station-scoped data isolation

INSTRUCTIONS: Open in Snowsight -> Click "Run All"
==============================================================================*/

-- 1. SSOT: Expiration date -- change ONLY here
SET DEMO_EXPIRES = '2026-07-06';

-- 2. Expiration check (informational — warns but does not block)
SELECT
    $DEMO_EXPIRES::DATE                                          AS expiration_date,
    CURRENT_DATE()                                               AS current_date,
    DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE)         AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) || ' days remaining'
    END AS demo_status;

-- 3. API integration (ACCOUNTADMIN required for CREATE API INTEGRATION)
USE ROLE ACCOUNTADMIN;
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

-- 4. Bootstrap warehouse (required before EXECUTE IMMEDIATE FROM)
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_AGENT_MULTICONTEXT_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 120
  COMMENT = 'DEMO: Agent multicontext compute (Expires: 2026-07-06)';
USE WAREHOUSE SFE_AGENT_MULTICONTEXT_WH;

-- 5. Fetch latest from Git
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_AGENT_MULTICONTEXT_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'DEMO: Agent multicontext Git repo (Expires: 2026-07-06)';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_AGENT_MULTICONTEXT_REPO FETCH;

-- 6. Execute scripts in order
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_AGENT_MULTICONTEXT_REPO/branches/main/demo-agent-multicontext/sql/01_schema_and_warehouse.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_AGENT_MULTICONTEXT_REPO/branches/main/demo-agent-multicontext/sql/02_tables_and_data.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_AGENT_MULTICONTEXT_REPO/branches/main/demo-agent-multicontext/sql/03_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_AGENT_MULTICONTEXT_REPO/branches/main/demo-agent-multicontext/sql/04_cortex_search.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_AGENT_MULTICONTEXT_REPO/branches/main/demo-agent-multicontext/sql/05_row_access_policies.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_AGENT_MULTICONTEXT_REPO/branches/main/demo-agent-multicontext/sql/06_roles_and_grants.sql';

-- 6. Final summary
SELECT
    'Agent Multicontext demo deployed successfully!' AS status,
    CURRENT_TIMESTAMP()                              AS completed_at,
    $DEMO_EXPIRES                                    AS expires;
