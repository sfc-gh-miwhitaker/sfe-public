/*==============================================================================
STREAMLIT DASHBOARD - Gaming Player Analytics
Deploys the 4-page Streamlit dashboard from the Git repository stage.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS;
USE WAREHOUSE SFE_GAMING_PLAYER_ANALYTICS_WH;

CREATE OR REPLACE STREAMLIT GAMING_PLAYER_ANALYTICS_APP
  FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-gaming-player-analytics/streamlit'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = SFE_GAMING_PLAYER_ANALYTICS_WH
  COMMENT = 'DEMO: Player analytics dashboard — cohorts, engagement, churn risk, feedback (Expires: 2026-04-24)';
