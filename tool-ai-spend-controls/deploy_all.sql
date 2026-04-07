/*==============================================================================
DEPLOY ALL — Cortex AI Functions Cost Governance Toolkit
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-07

Deploys:
  - Snowflake Notebook (SQL cells: monitoring + governance setup)
  - Streamlit dashboard (interactive usage analytics by day/week/month/year)

No tables are created by this script — both artifacts read from
SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY.
The notebook's governance cells create alert/task/procedure objects on demand.

Run All in Snowsight to deploy.
==============================================================================*/

-- ============================================================================
-- 1. EXPIRATION CHECK
-- ============================================================================
SELECT
    '2026-05-07'::DATE                                           AS expiration_date,
    CURRENT_DATE()                                               AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-05-07'::DATE)          AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-07'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-07'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-07'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-07'::DATE) || ' days remaining'
    END                                                          AS tool_status;

-- ============================================================================
-- 2. PREREQUISITES
-- ============================================================================
-- The notebook and Streamlit read SNOWFLAKE.ACCOUNT_USAGE views.
-- You need IMPORTED PRIVILEGES on the SNOWFLAKE database:
--   GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;

-- ============================================================================
-- 3. SHARED API INTEGRATION (idempotent)
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
    API_PROVIDER         = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/')
    ENABLED              = TRUE
    COMMENT              = 'Shared Git API integration for SFE monorepo (Expires: 2026-05-07)';

-- ============================================================================
-- 4. WAREHOUSE + DATABASE
-- ============================================================================
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared SFE demo/tool database';

CREATE WAREHOUSE IF NOT EXISTS SFE_AI_SPEND_CONTROLS_WH
    WAREHOUSE_SIZE       = 'XSMALL'
    AUTO_SUSPEND         = 60
    AUTO_RESUME          = TRUE
    INITIALLY_SUSPENDED  = TRUE
    COMMENT              = 'TOOL: Cortex AI cost governance (Expires: 2026-05-07)';

USE WAREHOUSE SFE_AI_SPEND_CONTROLS_WH;

-- ============================================================================
-- 5. GIT REPOSITORY
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
    COMMENT = 'Shared Git repository objects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
    API_INTEGRATION  = SFE_GIT_API_INTEGRATION
    ORIGIN           = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
    COMMENT          = 'SFE public monorepo';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- ============================================================================
-- 6. TOOL SCHEMA
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS
    COMMENT = 'TOOL: Cortex AI Functions cost governance (Expires: 2026-05-07)';

USE SCHEMA SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS;

-- ============================================================================
-- 7. NOTEBOOK
-- ============================================================================
CREATE OR REPLACE NOTEBOOK SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS.AI_SPEND_CONTROLS_NOTEBOOK
    FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-ai-spend-controls/'
    MAIN_FILE   = 'notebook.ipynb'
    COMMENT     = 'TOOL: Cortex AI Functions cost monitoring + governance setup (Expires: 2026-05-07)';

ALTER NOTEBOOK SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS.AI_SPEND_CONTROLS_NOTEBOOK
    ADD LIVE VERSION FROM LAST;

-- ============================================================================
-- 8. STREAMLIT DASHBOARD
-- ============================================================================
CREATE OR REPLACE STREAMLIT SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS.AI_SPEND_CONTROLS_DASHBOARD
    FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-ai-spend-controls/'
    MAIN_FILE   = 'streamlit_app.py'
    TITLE       = 'Cortex AI Functions — Cost Governance'
    COMMENT     = 'TOOL: Interactive AI function usage dashboard (Expires: 2026-05-07)';

-- ============================================================================
-- 9. SUMMARY
-- ============================================================================
SELECT
    'Deployment complete' AS status,
    'Open the notebook: Snowsight → Projects → Notebooks → AI_SPEND_CONTROLS_NOTEBOOK' AS notebook_path,
    'Open the dashboard: Snowsight → Projects → Streamlit → AI_SPEND_CONTROLS_DASHBOARD' AS streamlit_path,
    'Run notebook governance cells to create alerts, per-user limits, and runaway detection' AS next_step;
