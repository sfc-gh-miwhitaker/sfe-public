/*==============================================================================
DEPLOY ALL — Artist Analytics
Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

INSTRUCTIONS:
  1. Open Snowsight → New Worksheet
  2. Paste this entire file
  3. Click "Run All"
  Expected runtime: ~4 minutes

WHAT GETS CREATED:
  Database:  SNOWFLAKE_EXAMPLE (shared, if not exists)
  Schema:    SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS
  Schema:    SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS (shared, if not exists)
  Warehouse: SFE_ARTIST_ANALYTICS_WH
  Tables:    DIM_ARTIST, DIM_PLATFORM, DIM_SOCIAL_PLATFORM, DIM_SHOW
             FACT_DAILY_STREAMS, FACT_SOCIAL_METRICS, FACT_INCOME
  Views:     V_STREAM_KPI, V_SOCIAL_KPI, V_INCOME_KPI, V_SHOW_MOMENTUM
  Sem View:  SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_ARTIST_ANALYTICS
  Agent:     SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.ARTIST_ANALYTICS_AGENT
  Streamlit: SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.ARTIST_DASHBOARD

AFTER DEPLOY:
  Basic tier:
    Snowsight → Projects → Streamlit → ARTIST_DASHBOARD

  Pro tier (Snowflake Intelligence):
    Snowsight → AI & ML → Agents → ARTIST_ANALYTICS_AGENT → "Add to CoWork"
    Ask: "Which city has the best momentum score for my upcoming shows?"
==============================================================================*/

-- ── 1. Expiration check ───────────────────────────────────────────────────────
SELECT
    '2026-08-23'::DATE AS expiration_date,
    CURRENT_DATE()     AS today,
    DATEDIFF('day', CURRENT_DATE(), '2026-08-23'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-08-23'::DATE) < 0
        THEN 'EXPIRED — Code may use outdated syntax. Check the repo for an updated version.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-08-23'::DATE) <= 7
        THEN 'EXPIRING SOON — ' || DATEDIFF('day', CURRENT_DATE(), '2026-08-23'::DATE) || ' days remaining'
        ELSE 'ACTIVE — ' || DATEDIFF('day', CURRENT_DATE(), '2026-08-23'::DATE) || ' days remaining'
    END AS demo_status;

-- ── 2. Infrastructure ─────────────────────────────────────────────────────────
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'Shared database for SE demo projects';

CREATE WAREHOUSE IF NOT EXISTS SFE_ARTIST_ANALYTICS_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'DEMO: Artist analytics compute (Expires: 2026-08-23)';

USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;

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

-- ── 4. Deploy scripts ─────────────────────────────────────────────────────────
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/01_setup/01_create_schema.sql';

EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/02_data/01_dims.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/02_data/02_shows.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/02_data/03_streams.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/02_data/04_social.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/02_data/05_income.sql';

EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/03_views/01_kpi_views.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/03_views/02_momentum_score.sql';

EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/04_cortex/01_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/04_cortex/02_create_agent.sql';

EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-artist-analytics/sql/05_streamlit/01_create_streamlit.sql';

-- ── 5. Final validation ──────────────────────────────────────────────────────
SELECT
    'Artist Analytics — Jade Hollow'                                          AS demo,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.DIM_SHOW)        AS upcoming_shows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_DAILY_STREAMS) AS stream_rows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_SOCIAL_METRICS) AS social_rows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_INCOME)     AS income_rows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.V_SHOW_MOMENTUM) AS momentum_rows,
    'Snowsight → Projects → Streamlit → ARTIST_DASHBOARD'                    AS basic_tier,
    'Snowsight → AI & ML → Agents → ARTIST_ANALYTICS_AGENT'                  AS pro_tier;
