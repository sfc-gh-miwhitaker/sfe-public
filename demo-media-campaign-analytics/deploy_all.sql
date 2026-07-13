/*==============================================================================
DEPLOY ALL - Media Campaign Analytics
Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12

INSTRUCTIONS:
  1. Open Snowsight → New Worksheet
  2. Paste this entire file
  3. Click "Run All"
  Expected runtime: ~7 minutes

WHAT GETS CREATED:
  Database:  SNOWFLAKE_EXAMPLE (shared, if not exists)
  Schema:    SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS
  Schema:    SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS (shared, if not exists)
  Warehouse: SFE_MEDIA_CAMPAIGN_WH
  Tables:    DIM_CLIENT, DIM_CHANNEL, DIM_CAMPAIGN, FACT_DAILY_PERFORMANCE, DOC_CAMPAIGN_CONTENT
  View:      V_CAMPAIGN_KPI
  Search:    CAMPAIGN_DOCS_SEARCH (Cortex Search over campaign documents)
  Sem View:  SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS
  Agent:     SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.MEDIA_CAMPAIGN_AGENT

AFTER DEPLOY:
  1. Snowsight → AI & ML → Agents → MEDIA_CAMPAIGN_AGENT → "Add to CoWork"
  2. Open CoWork, select Campaign Analytics agent
  3. Try: "Which channel has the highest ROAS this year?"
  4. Try: "What was the creative strategy for Client Alpha's social campaigns?"
  5. Try: "Client Delta's CTV spend is high — why did we choose that channel?"
==============================================================================*/

-- ── 1. Expiration check ───────────────────────────────────────────────────────
SELECT
    '2026-08-12'::DATE AS expiration_date,
    CURRENT_DATE()     AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-08-12'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-08-12'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-08-12'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-08-12'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-08-12'::DATE) || ' days remaining'
    END AS demo_status;

-- ── 2. Infrastructure ─────────────────────────────────────────────────────────
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'Shared database for SE demo projects';

CREATE WAREHOUSE IF NOT EXISTS SFE_MEDIA_CAMPAIGN_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'DEMO: Media campaign analytics compute (Expires: 2026-08-12)';

USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for git repository integrations';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared schema for semantic views across SE demo projects';

-- ── 3. Git repo (fetch latest) ───────────────────────────────────────────────
CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Public SE demos monorepo';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- ── 4. Deploy scripts (single source of truth in sql/ subdirectories) ────────
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-media-campaign-analytics/sql/01_setup/01_create_schema.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-media-campaign-analytics/sql/02_data/01_create_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-media-campaign-analytics/sql/02_data/02_load_sample_data.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-media-campaign-analytics/sql/02_data/03_create_document_table.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-media-campaign-analytics/sql/02_data/04_load_documents.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-media-campaign-analytics/sql/03_transformations/01_create_views.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-media-campaign-analytics/sql/04_cortex/01_create_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-media-campaign-analytics/sql/04_cortex/01b_create_search_service.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-media-campaign-analytics/sql/04_cortex/02_create_agent.sql';

-- ── 5. Final validation ──────────────────────────────────────────────────────
SELECT
    'Media Campaign Analytics' AS demo,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CLIENT)             AS clients,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CAMPAIGN)           AS campaigns,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE) AS fact_rows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DOC_CAMPAIGN_CONTENT)   AS documents,
    'Snowsight → AI & ML → Agents → MEDIA_CAMPAIGN_AGENT'                                    AS next_step;
