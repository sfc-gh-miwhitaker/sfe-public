/*==============================================================================
DEPLOY ALL - Gaming Player Analytics
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-24
INSTRUCTIONS: Open in Snowsight -> Click "Run All"
==============================================================================*/

-- 1. Expiration check (informational -- warns but does not block)
SELECT
    '2026-04-24'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-04-24'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-04-24'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-04-24'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-04-24'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-04-24'::DATE) || ' days remaining'
    END AS demo_status;

-- 2. Shared infrastructure (idempotent -- safe to re-run)
USE ROLE ACCOUNTADMIN;
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_GAMING_PLAYER_ANALYTICS_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'DEMO: Gaming player analytics compute (Expires: 2026-04-24)';
USE WAREHOUSE SFE_GAMING_PLAYER_ANALYTICS_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Shared monorepo Git repository | Author: SE Community';

-- 3. Fetch latest from Git
ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- 4. Execute scripts in order
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/sql/01_setup/01_create_schema.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/sql/02_data/01_create_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/sql/02_data/02_load_sample_data.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/sql/03_transformations/01_dynamic_tables_profiles.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/sql/03_transformations/02_dynamic_tables_engagement.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/sql/03_transformations/03_ai_enrichment.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/sql/03_transformations/04_dynamic_tables_facts.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/sql/04_cortex/01_create_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/sql/04_cortex/02_create_agent.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/sql/05_streamlit/01_create_dashboard.sql';

-- 5. Final summary
SELECT
    'Deployment complete!' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    '2026-04-24' AS expires,
    'SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS' AS schema_name,
    'Navigate to Projects > Streamlit to open the dashboard' AS next_step;
