/*******************************************************************************
 * DEMO METADATA (Machine-readable - Do not modify format)
 * PROJECT_NAME: IoT Lifecycle Demo -- Agentic Operations Engine
 * AUTHOR: Pair-programmed by SE Community + Cortex Code
 * CREATED: 2026-05-12
 * EXPIRES: 2026-06-11
 * GITHUB_REPO: https://github.com/sfc-gh-miwhitaker/sfe-public
 * PURPOSE: End-to-end IoT lifecycle demo with zombie garment detection,
 *          retention alerts, route efficiency analysis, real-time fleet map,
 *          and dual Cortex Agents (CFO + Operations) -- all synthetic data.
 *
 * DEPLOYMENT INSTRUCTIONS:
 * 1. Open Snowsight (https://app.snowflake.com)
 * 2. Copy this ENTIRE script
 * 3. Paste into a new SQL worksheet
 * 4. Click "Run All" (or press Cmd/Ctrl + Enter repeatedly)
 * 5. Monitor output for any errors
 ******************************************************************************/

SET DEMO_EXPIRES = '2026-06-11';

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

USE ROLE ACCOUNTADMIN;
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_IOT_LIFECYCLE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'DEMO: IoT Lifecycle compute (Expires: 2026-06-11)';
USE WAREHOUSE SFE_IOT_LIFECYCLE_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Shared monorepo Git repository | Author: SE Community';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-iot-lifecycle/sql/01_setup/01_create_database.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-iot-lifecycle/sql/01_setup/02_create_schemas.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-iot-lifecycle/sql/02_data/01_create_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-iot-lifecycle/sql/02_data/02_load_sample_data.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-iot-lifecycle/sql/03_transformations/01_create_views.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-iot-lifecycle/sql/03_transformations/02_create_stream_and_task.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-iot-lifecycle/sql/04_cortex/01_create_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-iot-lifecycle/sql/04_cortex/02_create_agent.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-iot-lifecycle/sql/05_spcs/01_create_infra.sql';

SELECT
    'IoT Lifecycle data + agents (CFO + Operations) deployed. SPCS infra ready.' AS status,
    'NEXT: Build & push image, then run deploy_service.sql'  AS next_step,
    CURRENT_TIMESTAMP()                                      AS completed_at,
    $DEMO_EXPIRES                                            AS expires;
