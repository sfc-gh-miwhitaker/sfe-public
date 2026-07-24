/*==============================================================================
05_STREAMLIT — Create the Streamlit-in-Snowflake dashboard from the Git stage
Cortex AI Cost Controls demo | Expires: 2026-07-24

Warehouse-runtime Streamlit sourced from the shared monorepo Git repository.
The app/ directory (streamlit_app.py + pages/) is staged at the path below after
deploy_all.sql runs ALTER GIT REPOSITORY ... FETCH.
==============================================================================*/

USE ROLE SYSADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS;
USE WAREHOUSE SFE_CORTEX_AI_COST_CONTROLS_WH;

CREATE OR REPLACE STREAMLIT CORTEX_AI_COST_DASHBOARD
    FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-cortex-ai-cost-controls/app'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = SFE_CORTEX_AI_COST_CONTROLS_WH
    COMMENT = 'DEMO: Cortex AI cost monitoring & controls dashboard (Expires: 2026-07-24)';

-- Publish the live version so users with USAGE can view it.
ALTER STREAMLIT CORTEX_AI_COST_DASHBOARD ADD LIVE VERSION FROM LAST;

SELECT 'Streamlit dashboard created: CORTEX_AI_COST_DASHBOARD' AS step_05_streamlit;
