-- ============================================================================
-- Script: sql/04_streamlit/01_create_dashboard.sql
-- Purpose: Create the Streamlit dashboard for quality metrics.
-- Target: SNOWFLAKE_EXAMPLE.DATA_QUALITY.DATA_QUALITY_DASHBOARD Streamlit app.
-- Deps: Git repo stage, warehouse, and V_DATA_QUALITY_METRICS view exist.
-- Note: Uses FROM (not ROOT_LOCATION) per current Snowflake best practices.
-- ============================================================================

CREATE OR REPLACE STREAMLIT SNOWFLAKE_EXAMPLE.DATA_QUALITY.DATA_QUALITY_DASHBOARD
  FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/streamlit'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = 'SFE_DATA_QUALITY_WH'
  COMMENT = 'DEMO: Data quality dashboard | Author: SE Community | Expires: 2026-05-01';
