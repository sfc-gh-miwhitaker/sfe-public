/*==============================================================================
DEPLOY ALL — Cortex AI Cost Controls (demo)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-07-24
INSTRUCTIONS: Open in Snowsight -> Click "Run All"

Self-contained. Creates shared infra inline (IF NOT EXISTS), fetches this repo
from Git, then runs the project SQL in order and publishes the Streamlit app.
Reads LIVE SNOWFLAKE.ACCOUNT_USAGE views — no synthetic data.
==============================================================================*/

-- 1. Expiration check (informational — warns but does not block)
SELECT
    '2026-07-24'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-07-24'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-07-24'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-07-24'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-07-24'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-07-24'::DATE) || ' days remaining'
    END AS demo_status;

-- 2. Shared infrastructure (idempotent — safe to re-run)
USE ROLE ACCOUNTADMIN;
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_CORTEX_AI_COST_CONTROLS_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 3600
  COMMENT = 'DEMO: Cortex AI cost controls compute (Expires: 2026-07-24)';
USE WAREHOUSE SFE_CORTEX_AI_COST_CONTROLS_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Shared monorepo Git repository | Author: SE Community';

-- 3. Fetch latest from Git
ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- 4. Execute project scripts in order
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-cortex-ai-cost-controls/sql/01_setup/01_create_schema.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-cortex-ai-cost-controls/sql/02_views/01_app_views.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-cortex-ai-cost-controls/sql/03_enforcement/01_enforcement.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-cortex-ai-cost-controls/sql/04_budget/01_account_budget.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-cortex-ai-cost-controls/sql/05_streamlit/01_create_streamlit.sql';

-- 5. Final summary (the headline result of Run All)
USE ROLE SYSADMIN;
SELECT 'Deployment complete! Open Projects -> Streamlit -> CORTEX_AI_COST_DASHBOARD' AS status,
       CURRENT_TIMESTAMP() AS completed_at;
