/*==============================================================================
DEPLOY ALL - Casino Campaign Recommendation Engine
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-01
INSTRUCTIONS: Open in Snowsight -> Click "Run All"

ML-powered campaign targeting + vector-based player lookalike matching.
==============================================================================*/

-- 1. SSOT: Expiration date -- change ONLY here, then run: sync-expiration
SET DEMO_EXPIRES = '2026-04-01';

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
CREATE WAREHOUSE IF NOT EXISTS SFE_CAMPAIGN_ENGINE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Campaign engine compute (Expires: 2026-04-01)';
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

-- 4. Fetch latest from Git
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'DEMO: Campaign engine Git repo (Expires: 2026-04-01)';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO FETCH;

-- 5. Execute scripts in order
-- 5a. Setup
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/01_setup/01_create_schema.sql';

-- 5b. Data model & sample data
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/02_data/01_create_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/02_data/02_load_sample_data.sql';

-- 5c. Feature engineering pipeline
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/03_features/01_player_features.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/03_features/02_player_vectors.sql';

-- 5d. Recommendation engine
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/04_engine/01_lookalike_procedure.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/04_engine/02_campaign_classifier.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/04_engine/03_campaign_recommendations.sql';

-- 5e. Cortex Intelligence
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/05_cortex/01_create_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/05_cortex/02_create_agent.sql';

-- 5f. Streamlit Dashboard
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/sql/06_streamlit/01_create_dashboard.sql';

-- 6. Final summary (ONLY visible result in Run All)
SELECT
    'Campaign Engine deployed successfully!' AS status,
    CURRENT_TIMESTAMP()                      AS completed_at,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.RAW_PLAYERS) AS players_loaded,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.RAW_PLAYER_ACTIVITY) AS activities_loaded,
    $DEMO_EXPIRES                            AS expires;
