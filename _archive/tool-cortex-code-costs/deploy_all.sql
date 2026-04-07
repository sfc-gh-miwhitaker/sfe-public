/*==============================================================================
DEPLOY ALL - Cortex Code Usage & Cost Tools
Pair-programmed by SE Community + Cortex Code | Expires: 2026-07-06

Deploys two artifacts for surfacing Cortex Code costs (CLI + Snowsight) from
SNOWFLAKE.ACCOUNT_USAGE:
  - notebook.ipynb  — grab-and-run Snowflake Notebook (8 Python cells)
  - streamlit_app.py — interactive Streamlit dashboard (4 tabs, source picker)

No schema objects or tables are created — both tools read ACCOUNT_USAGE directly.

INSTRUCTIONS: Open in Snowsight → Run All
==============================================================================*/

-- ============================================================================
-- 1. EXPIRATION CHECK (informational — warns but does not block)
-- ============================================================================
SELECT
    '2026-07-06'::DATE                                           AS expiration_date,
    CURRENT_DATE()                                               AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-07-06'::DATE)          AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-07-06'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-07-06'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-07-06'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-07-06'::DATE) || ' days remaining'
    END AS tool_status;

-- ============================================================================
-- 2. PREREQUISITE CHECK
-- The notebook and Streamlit read SNOWFLAKE.ACCOUNT_USAGE. If your role does
-- not yet have IMPORTED PRIVILEGES on the SNOWFLAKE database, run this once
-- as ACCOUNTADMIN before proceeding:
--
--   GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE SYSADMIN;
--
-- ============================================================================

-- ============================================================================
-- 3. SHARED INFRASTRUCTURE (ACCOUNTADMIN required for API integration)
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
    ENABLED = TRUE
    COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

-- ============================================================================
-- 4. WAREHOUSE + DATABASE (SYSADMIN)
-- ============================================================================
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE demonstration projects and tools | Author: SE Community';

CREATE WAREHOUSE IF NOT EXISTS SFE_TOOLS_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 120
    COMMENT = 'Shared warehouse for Snowflake Tools Collection | Author: SE Community';

USE WAREHOUSE SFE_TOOLS_WH;

-- ============================================================================
-- 5. GIT REPOSITORY (shared across all sfe-public projects)
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
    COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
    API_INTEGRATION = SFE_GIT_API_INTEGRATION
    ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
    COMMENT = 'Shared monorepo Git repository | Author: SE Community';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- ============================================================================
-- 6. TOOL SCHEMA
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.CORTEX_CODE_COSTS
    COMMENT = 'TOOL: Cortex Code CLI + Snowsight usage & cost tools (Expires: 2026-07-06)';

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_CODE_COSTS;

-- ============================================================================
-- 7. DEPLOY NOTEBOOK
-- ============================================================================
CREATE OR REPLACE NOTEBOOK SNOWFLAKE_EXAMPLE.CORTEX_CODE_COSTS.CORTEX_CODE_COSTS_NOTEBOOK
    FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-code-costs/'
    MAIN_FILE = 'notebook.ipynb'
    QUERY_WAREHOUSE = SFE_TOOLS_WH
    COMMENT = 'TOOL: Cortex Code CLI + Snowsight usage & cost notebook (Expires: 2026-07-06)';

ALTER NOTEBOOK SNOWFLAKE_EXAMPLE.CORTEX_CODE_COSTS.CORTEX_CODE_COSTS_NOTEBOOK
    ADD LIVE VERSION FROM LAST;

-- ============================================================================
-- 8. DEPLOY STREAMLIT APP
-- ============================================================================
CREATE OR REPLACE STREAMLIT SNOWFLAKE_EXAMPLE.CORTEX_CODE_COSTS.CORTEX_CODE_COSTS_APP
    FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-cortex-code-costs/'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = SFE_TOOLS_WH
    COMMENT = 'TOOL: Cortex Code CLI + Snowsight cost dashboard (Expires: 2026-07-06)'
    TITLE = 'Cortex Code Costs';

ALTER STREAMLIT SNOWFLAKE_EXAMPLE.CORTEX_CODE_COSTS.CORTEX_CODE_COSTS_APP
    ADD LIVE VERSION FROM LAST;

-- ============================================================================
-- 9. DEPLOYMENT SUMMARY
-- ============================================================================
SELECT
    'Deployment complete!' AS status,
    'Snowsight > Projects > Notebooks > CORTEX_CODE_COSTS_NOTEBOOK' AS notebook,
    'Snowsight > Projects > Streamlit > CORTEX_CODE_COSTS_APP'      AS streamlit,
    CURRENT_TIMESTAMP()                                              AS completed_at;
