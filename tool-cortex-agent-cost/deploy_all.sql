/******************************************************************************
 * Tool: Cortex Agent Cost
 * File: deploy_all.sql
 * Author: SE Community
 * Created: 2026-03-23
 * Expires: 2026-04-22
 *
 * Prerequisites:
 *   ACCOUNTADMIN role access (for API integration)
 *
 * How to Deploy:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 *
 * What This Creates:
 *   - Schema: SNOWFLAKE_EXAMPLE.CORTEX_AGENT_COST
 *   - Warehouse: SFE_CORTEX_AGENT_COST_WH
 *   - Config table: AGENT_COST_CONFIG
 *   - Views: 11 monitoring views (detail, granular, summary)
 *   - Streamlit: CORTEX_AGENT_COST_APP (5-page dashboard)
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (Informational -- warns but does not block deployment)
-- ============================================================================
SELECT
    '2026-04-22'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-04-22'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-04-22'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-04-22'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-04-22'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-04-22'::DATE) || ' days remaining'
    END AS tool_status;

-- ============================================================================
-- SHARED INFRASTRUCTURE (idempotent -- safe to re-run)
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_CORTEX_AGENT_COST_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'TOOL: Cortex Agent Cost compute (Expires: 2026-04-22)';
USE WAREHOUSE SFE_CORTEX_AGENT_COST_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Shared monorepo Git repository | Author: SE Community';

-- ============================================================================
-- FETCH LATEST CODE (monorepo Git integration)
-- ============================================================================
ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- ============================================================================
-- EXECUTE SCRIPTS IN ORDER
-- ============================================================================
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/01_setup/01_schema_and_warehouse.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/02_config/01_config_table.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/01_agent_detail.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/02_intelligence_detail.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/03_combined.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/04_token_granular.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/05_credit_granular.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/06_daily_summary.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/07_agent_cost_summary.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/08_model_cost_summary.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/09_user_agent_spend.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/10_cache_efficiency.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/03_views/11_forecast_base.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-agent-cost/sql/04_streamlit/01_create_streamlit.sql';

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    'DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Cortex Agent Cost' AS tool,
    '2026-04-22' AS expires,
    'Open Projects > Streamlit > CORTEX_AGENT_COST_APP' AS next_step;
