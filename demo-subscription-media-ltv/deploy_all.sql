/*==============================================================================
DEPLOY ALL - Subscription Media LTV: governed member value in CoWork
Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-16

INSTRUCTIONS:
  Open Snowsight -> New SQL Worksheet -> paste this file -> Run All.
  Runtime: about 5 minutes on an XSMALL warehouse (the churn model trains in
  about 1 minute).

WHAT GETS CREATED:
  Warehouse        SFE_SUBSCRIPTION_MEDIA_LTV_WH (XSMALL, auto-suspend 60s)
  Schema           SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV
  Tables           ACQUISITION_SOURCES, PAYMENT_PLATFORMS, OFFER_FUNNEL,
                   FREE_AUDIENCE, AD_SEGMENTS, MEMBERS, SUBSCRIPTION_PAYMENTS,
                   VIEWING_MONTHLY, ACQUISITION_SPEND, CHURN_SCORES,
                   CHURN_FEATURE_IMPORTANCE, CHURN_MODEL_METRICS
  Views            MEMBER_VALUE, DISCOUNT_ECONOMICS, AD_SEGMENT_ECONOMICS,
                   CHURN_FEATURES, CHURN_TRAINING_DATA
  ML model         CHURN_MODEL (SNOWFLAKE.ML.CLASSIFICATION)
  Semantic views   SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_SUBSCRIPTION_MEDIA_LTV_MEMBER_VALUE
                   SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_SUBSCRIPTION_MEDIA_LTV_RAW
  Cortex Agents    MEMBER_VALUE_AGENT ("Member Value Analyst")
                   RAW_DATA_AGENT ("Raw Data Assistant (no business context)")
  Shared (reused if present): SFE_GIT_API_INTEGRATION, SNOWFLAKE_EXAMPLE
  database, GIT_REPOS and SEMANTIC_MODELS schemas, SFE_DEMOS_REPO Git repository.

AFTER DEPLOY:
  1. Open Snowflake CoWork with the SYSADMIN role.
  2. Pick "Member Value Analyst" and ask the questions in docs/01-DEMO-SCRIPT.md.
  3. Ask the first question again with "Raw Data Assistant (no business
     context)" to show the same data without governed definitions.

All data is synthetic. No real company, member, or financial data is used.
==============================================================================*/

-- 1. Expiration check (informational, never blocks)
SELECT
    '2027-01-16'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2027-01-16'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2027-01-16'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2027-01-16'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2027-01-16'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2027-01-16'::DATE) || ' days remaining'
    END AS demo_status;

-- 2. Shared infrastructure (idempotent)
USE ROLE ACCOUNTADMIN;
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';
GRANT USAGE ON INTEGRATION SFE_GIT_API_INTEGRATION TO ROLE SYSADMIN;

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_SUBSCRIPTION_MEDIA_LTV_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 3600
  COMMENT = 'DEMO: Subscription media LTV compute (Expires: 2027-01-16)';
USE WAREHOUSE SFE_SUBSCRIPTION_MEDIA_LTV_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Shared monorepo Git repository | Author: SE Community';

-- 3. Fetch latest from Git
ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- 4. Build the demo
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-subscription-media-ltv/sql/01_setup/01_create_schema.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-subscription-media-ltv/sql/02_tables/01_reference_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-subscription-media-ltv/sql/02_tables/02_generate_members_and_activity.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-subscription-media-ltv/sql/03_transformations/01_member_value_views.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-subscription-media-ltv/sql/04_cortex/01_churn_model.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-subscription-media-ltv/sql/04_cortex/02_semantic_views.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-subscription-media-ltv/sql/04_cortex/03_agents.sql';

-- 5. Show both agents in CoWork (needs MODIFY on the CoWork object)
USE ROLE ACCOUNTADMIN;
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-subscription-media-ltv/sql/04_cortex/04_attach_cowork.sql';
USE ROLE SYSADMIN;

-- 6. Final summary (the only visible Run All result)
SELECT
    'Subscription Media LTV' AS demo,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.MEMBERS) AS members,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.SUBSCRIPTION_PAYMENTS) AS payments,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.CHURN_SCORES) AS members_scored_for_churn,
    (SELECT MAX(metric_value) FROM SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.CHURN_MODEL_METRICS
      WHERE metric_name = 'auc' AND average_type = 'macro') AS churn_model_auc,
    'Open CoWork as SYSADMIN and pick Member Value Analyst' AS next_step;
