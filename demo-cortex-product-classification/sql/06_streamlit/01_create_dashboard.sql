/*==============================================================================
STREAMLIT DASHBOARD - Glaze & Classify
Interactive comparison dashboard for classification approaches.
Uses the FROM parameter (recommended approach, supports Git integration).
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

CREATE OR REPLACE STREAMLIT GLAZE_CLASSIFY_DASHBOARD
  FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/streamlit'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = SFE_GLAZE_AND_CLASSIFY_WH
  COMMENT = 'DEMO: Classification comparison dashboard (Expires: 2026-03-20)'
  TITLE = 'Glaze & Classify';
