/*==============================================================================
STREAMLIT DASHBOARD
Generated from prompt: "Deploy the Streamlit dashboard from Git repo stage."
Tool: Cursor + Claude | Refined: 1 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

CREATE OR REPLACE STREAMLIT CAMPAIGN_ENGINE_DASHBOARD
  FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/streamlit'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = SFE_CAMPAIGN_ENGINE_WH
  TITLE = 'Casino Campaign Engine'
  COMMENT = 'DEMO: Campaign targeting and player lookalike dashboard (Expires: 2026-05-01)';

ALTER STREAMLIT CAMPAIGN_ENGINE_DASHBOARD ADD LIVE VERSION FROM LAST;
