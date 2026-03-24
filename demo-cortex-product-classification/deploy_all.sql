/*==============================================================================
DEPLOY ALL - Glaze & Classify
Author: SE Community | Expires: 2026-07-01
INSTRUCTIONS: Open in Snowsight → Click "Run All"

Product classification showdown: traditional SQL vs Cortex AI vs SPCS vision.
==============================================================================*/

-- 1. SSOT: Expiration date — change ONLY here
SET DEMO_EXPIRES = '2026-07-01';

-- 2. Expiration check (informational — warns but does not block)
SELECT
    $DEMO_EXPIRES::DATE                                          AS expiration_date,
    CURRENT_DATE()                                               AS current_date,
    DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE)         AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) || ' days remaining'
    END AS demo_status;

-- 3. API integration (ACCOUNTADMIN required for CREATE API INTEGRATION)
USE ROLE ACCOUNTADMIN;
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

-- 4. Bootstrap warehouse (required before EXECUTE IMMEDIATE FROM)
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_GLAZE_AND_CLASSIFY_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Glaze & Classify compute (Expires: 2026-07-01)';
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

-- 5. Fetch latest from Git
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'DEMO: Glaze & Classify Git repo (Expires: 2026-07-01)';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO FETCH;

-- 6. Execute scripts in order
-- 5a. Setup
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/01_setup/01_create_schema.sql';

-- 5b. Data model & sample data
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/02_data/01_create_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/02_data/02_load_sample_data.sql';

-- 5c. Classification approaches
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/03_classification/01_traditional_sql.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/03_classification/02_cortex_simple.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/03_classification/03_cortex_robust.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/03_classification/04_comparison_view.sql';

-- 5d. SPCS Vision — infrastructure
--     Service starts async; steps 5e-5f run while the container comes up.
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/05_spcs/01_create_image_service.sql';

-- 5e. Cortex Intelligence (runs while SPCS service starts in the background)
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/04_cortex/01_create_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/04_cortex/02_create_agent.sql';

-- 5f. SPCS Vision — populate (waits for service READY, then classifies)
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/05_spcs/02_populate_vision.sql';

-- 5g. Streamlit Dashboard
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/demo-cortex-product-classification/sql/06_streamlit/01_create_dashboard.sql';

-- 6. Final summary (ONLY visible result in Run All)
SELECT
    CASE
        WHEN simple_ct = 0 OR robust_ct = 0 OR vision_ct = 0
        THEN '⚠️  DEPLOYED WITH WARNINGS — classification tables may be empty'
        ELSE '✅ Glaze & Classify deployed successfully!'
    END                            AS status,
    CURRENT_TIMESTAMP()            AS completed_at,
    products_loaded,
    trad_ct                        AS traditional_classified,
    simple_ct                      AS cortex_simple_classified,
    robust_ct                      AS cortex_robust_classified,
    vision_ct                      AS vision_classified,
    $DEMO_EXPIRES                  AS expires
FROM (
    SELECT
        (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.RAW_PRODUCTS)               AS products_loaded,
        (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.STG_CLASSIFIED_TRADITIONAL)  AS trad_ct,
        (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.STG_CLASSIFIED_CORTEX_SIMPLE) AS simple_ct,
        (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.STG_CLASSIFIED_CORTEX_ROBUST) AS robust_ct,
        (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.STG_CLASSIFIED_VISION)       AS vision_ct
);
