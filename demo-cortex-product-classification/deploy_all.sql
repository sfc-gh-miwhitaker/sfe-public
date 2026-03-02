/*==============================================================================
DEPLOY ALL - Glaze & Classify
Author: SE Community | Expires: 2026-03-20
INSTRUCTIONS: Open in Snowsight → Click "Run All"

Product classification showdown: traditional SQL vs Cortex AI vs SPCS vision.
==============================================================================*/

-- 1. SSOT: Expiration date — change ONLY here, then run: sync-expiration
SET DEMO_EXPIRES = '2026-03-20';

-- 2. Expiration check
DECLARE
  demo_expired EXCEPTION (-20001, 'DEMO EXPIRED - contact owner');
BEGIN
  IF (CURRENT_DATE() > $DEMO_EXPIRES::DATE) THEN
    RAISE demo_expired;
  END IF;
END;

-- 3. Bootstrap warehouse (required before EXECUTE IMMEDIATE FROM)
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_GLAZE_AND_CLASSIFY_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Glaze & Classify compute (Expires: 2026-03-20)';
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

-- 4. Fetch latest from Git
CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/glaze-and-classify.git'
  COMMENT = 'DEMO: Glaze & Classify Git repo (Expires: 2026-03-20)';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO FETCH;

-- 5. Execute scripts in order
-- 5a. Setup
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/01_setup/01_create_schema.sql';

-- 5b. Data model & sample data
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/02_data/01_create_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/02_data/02_load_sample_data.sql';

-- 5c. Classification approaches
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/01_traditional_sql.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/02_cortex_simple.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/03_cortex_robust.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/04_comparison_view.sql';

-- 5d. SPCS Vision — infrastructure (optional, requires CREATE COMPUTE POOL)
--     Service starts async; steps 5e-5f run while the container comes up.
BEGIN
  EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/05_spcs/01_create_image_service.sql';
EXCEPTION
  WHEN OTHER THEN
    SYSTEM$LOG_INFO('Skipping SPCS vision service: ' || SQLERRM);
END;

-- 5e. Cortex Intelligence (runs while SPCS service starts in the background)
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/04_cortex/01_create_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/04_cortex/02_create_agent.sql';

-- 5f. SPCS Vision — populate (waits for service READY, then classifies)
BEGIN
  EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/05_spcs/02_populate_vision.sql';
EXCEPTION
  WHEN OTHER THEN
    SYSTEM$LOG_INFO('Skipping SPCS vision populate: ' || SQLERRM);
END;

-- 5g. Streamlit Dashboard
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/06_streamlit/01_create_dashboard.sql';

-- 6. Final summary (ONLY visible result in Run All)
SELECT
    'Glaze & Classify deployed successfully!' AS status,
    CURRENT_TIMESTAMP()                       AS completed_at,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.RAW_PRODUCTS) AS products_loaded,
    $DEMO_EXPIRES                             AS expires;
