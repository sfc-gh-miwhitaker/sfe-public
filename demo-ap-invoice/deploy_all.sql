/*==============================================================================
DEPLOY ALL - AP Invoice Pipeline
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-08
INSTRUCTIONS: Open in Snowsight -> Click "Run All"
==============================================================================*/

-- 1. Expiration check (informational -- warns but does not block)
SELECT
    '2026-05-08'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-05-08'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-08'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-08'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-08'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-08'::DATE) || ' days remaining'
    END AS demo_status;

-- 2. Shared infrastructure (idempotent -- safe to re-run)
USE ROLE ACCOUNTADMIN;
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

-- Grant Cortex AI function access
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SYSADMIN;

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.AP_INVOICE
  COMMENT = 'DEMO: AP Invoice automation with AI_EXTRACT and AI_CLASSIFY (Expires: 2026-05-08)';

CREATE WAREHOUSE IF NOT EXISTS SFE_AP_INVOICE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'DEMO: AP Invoice Pipeline compute (Expires: 2026-05-08)';
USE WAREHOUSE SFE_AP_INVOICE_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Shared monorepo Git repository | Author: SE Community';

-- 3. Fetch latest from Git
ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- 4. Execute scripts in order
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-ap-invoice/sql/01_setup/01_create_schema.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-ap-invoice/sql/02_data/01_load_sample_data.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-ap-invoice/sql/03_transformations/01_create_views.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-ap-invoice/sql/03_transformations/02_create_stream_and_task.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-ap-invoice/sql/04_cortex/01_ai_extract_patterns.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-ap-invoice/sql/04_cortex/02_ai_classify_gl_codes.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-ap-invoice/sql/04_cortex/03_create_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-ap-invoice/sql/05_streamlit/01_create_dashboard.sql';

-- 5. Final summary (ONLY visible result in Run All)
SELECT 'Deployment complete!' AS status, CURRENT_TIMESTAMP() AS completed_at;
