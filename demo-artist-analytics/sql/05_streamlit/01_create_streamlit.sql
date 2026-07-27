/*==============================================================================
  05_streamlit/01_create_streamlit.sql
  Artist Analytics — Streamlit Dashboard (Basic Tier)
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

  Warehouse-runtime Streamlit sourced from the shared monorepo Git repository.
  After deploy: Snowsight → Projects → Streamlit → ARTIST_DASHBOARD
==============================================================================*/

USE ROLE SYSADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;

CREATE OR REPLACE STREAMLIT ARTIST_DASHBOARD
    FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/app'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = SFE_ARTIST_ANALYTICS_WH
    COMMENT = 'DEMO: Artist analytics dashboard — basic tier (Expires: 2026-08-23)';

ALTER STREAMLIT ARTIST_DASHBOARD ADD LIVE VERSION FROM LAST;

SELECT 'Streamlit ARTIST_DASHBOARD created: Snowsight → Projects → Streamlit → ARTIST_DASHBOARD' AS step_05_streamlit;
