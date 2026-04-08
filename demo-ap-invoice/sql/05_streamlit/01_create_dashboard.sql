/*==============================================================================
STREAMLIT DASHBOARD - AP Invoice Pipeline
Deploys the 3-panel Streamlit app from the Git repository.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-08
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.AP_INVOICE;

CREATE OR REPLACE STREAMLIT AP_INVOICE_DASHBOARD
    FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-ap-invoice/streamlit'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = SFE_AP_INVOICE_WH
    TITLE = 'AP Invoice Pipeline'
    COMMENT = 'DEMO: 3-panel AP invoice dashboard - status, review queue, analytics chat (Expires: 2026-05-08)';

ALTER STREAMLIT AP_INVOICE_DASHBOARD ADD LIVE VERSION FROM LAST;

SHOW STREAMLITS LIKE 'AP_INVOICE_DASHBOARD' IN SCHEMA SNOWFLAKE_EXAMPLE.AP_INVOICE;

SELECT 'Streamlit dashboard deployed — open in Snowsight to use' AS status;
