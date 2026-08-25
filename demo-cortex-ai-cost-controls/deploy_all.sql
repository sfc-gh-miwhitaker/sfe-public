/*==============================================================================
DEPLOY ALL - Cortex AI Cost Controls
Pair-programmed by SE Community + Cortex Code | Expires: 2027-02-25

INSTRUCTIONS:
  1. Open Snowsight → New Worksheet
  2. Paste this entire file
  3. Click "Run All"
  Expected runtime: ~2 minutes

WHAT GETS CREATED:
  Database:   SNOWFLAKE_EXAMPLE (shared, if not exists)
  Schema:     SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS
  Warehouse:  SFE_CORTEX_AI_COST_CONTROLS_WH
  Tables:     MAT_AI_USAGE_UNIFIED, MAT_AI_SPEND_DAILY,
              MAT_AI_SPEND_BY_USER, MAT_AGENT_ATTRIBUTION
  Procedure:  SP_REFRESH_COST_MATERIALIZATION
  Task:       TASK_REFRESH_COST_MATERIALIZATION (ships SUSPENDED)
  Quota:      AI_COST_QUOTA (skipped if QUOTA_CREATOR role unavailable)

AFTER DEPLOY:
  1. cd app && snow app deploy
  2. Open Snowsight → Apps → AI Cost Controls
  3. Dashboard shows live Cortex AI spend, per-user attribution, quota status, and trends

PREREQUISITES:
  - SYSADMIN + ACCOUNTADMIN roles available
  - API integration SFE_GIT_API_INTEGRATION exists (run shared/setup_git_integration.sql if not)
  - SNOWFLAKE database imported privileges (granted below)
==============================================================================*/

-- ── 1. Expiration check ───────────────────────────────────────────────────────
SELECT
    '2027-02-25'::DATE AS expiration_date,
    CURRENT_DATE()     AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2027-02-25'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2027-02-25'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2027-02-25'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2027-02-25'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2027-02-25'::DATE) || ' days remaining'
    END AS demo_status;

-- ── 2. Minimal infrastructure (required before Git repo can be created) ───────
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'Shared database for SE demo projects';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for git repository integrations';

-- ── 3. Git repo (fetch latest) ────────────────────────────────────────────────
CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Public SE demos monorepo';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- ── 4. Deploy scripts ─────────────────────────────────────────────────────────
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-cortex-ai-cost-controls/sql/01_setup/01_create_schema.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-cortex-ai-cost-controls/sql/02_materialization/01_tables_and_task.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-cortex-ai-cost-controls/sql/03_quota_example/01_quota_setup.sql';

-- ── 5. Final validation ───────────────────────────────────────────────────────
SELECT
    'Cortex AI Cost Controls' AS demo,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS.MAT_AI_USAGE_UNIFIED)  AS usage_rows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS.MAT_AI_SPEND_DAILY)    AS daily_spend_rows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS.MAT_AI_SPEND_BY_USER)  AS user_spend_rows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS.MAT_AGENT_ATTRIBUTION) AS agent_rows,
    'cd app && snow app deploy' AS next_step;
