/*==============================================================================
STREAMLIT DASHBOARD - Music Label Marketing Analytics
5-page dashboard: Budget Entry, Budget vs Actual, Campaign Performance,
Artist Profile, Anomaly Alerts.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.MUSIC_MARKETING;
USE WAREHOUSE SFE_MUSIC_MARKETING_WH;

CREATE OR REPLACE STREAMLIT MUSIC_MARKETING_APP
  FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-music-label-marketing-analytics/streamlit'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = SFE_MUSIC_MARKETING_WH
  COMMENT = 'DEMO: Music label marketing analytics dashboard — 5 pages including spreadsheet-style budget entry (Expires: 2026-04-24)';
