/******************************************************************************
 * Tool: DR Cost Agent (Snowflake Intelligence)
 * File: deploy_dcm.sql
 * Author: SE Community
 * Expires: 2026-05-01
 *
 * DCM-based deployment: declarative infrastructure + post-hooks for
 * unsupported object types. Replaces the imperative EXECUTE IMMEDIATE chain
 * with a plan-then-deploy workflow for schema, table, views, and grants.
 *
 * Prerequisites:
 *   ACCOUNTADMIN + SYSADMIN role access
 *   DCM Projects enabled (Preview feature as of March 2026)
 *
 * How to Deploy:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 *
 * Alternative: use Snowflake CLI for plan-before-deploy workflow
 *   cd tool-dr-cost-agent/dcm/
 *   snow dcm plan
 *   snow dcm deploy
 *   -- then run post-hooks manually or via snow sql
 *
 * What This Creates:
 *   DCM-managed: Schema DR_COST_AGENT, Table PRICING_CURRENT,
 *     Views DB_METADATA_V2 / HYBRID_TABLE_METADATA / REPLICATION_HISTORY,
 *     Grants on managed objects
 *   Post-hooks: Procedures COST_PROJECTION / UPDATE_PRICING,
 *     Semantic View SV_DR_COST, Agent DR_COST_AGENT, seed data, grants
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (informational -- warns but does not block)
-- ============================================================================
SELECT
    '2026-05-01'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) || ' days remaining'
    END AS tool_status;

-- ============================================================================
-- PRE-HOOKS: Shared infrastructure that DCM cannot manage
-- These objects are shared across projects and must not be DCM-managed
-- (removing a DEFINE would drop them, breaking other projects).
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
  ENABLED = TRUE
  COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

GRANT DATABASE ROLE SNOWFLAKE.USAGE_VIEWER TO ROLE SYSADMIN;

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;

CREATE WAREHOUSE IF NOT EXISTS SFE_TOOLS_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Shared warehouse for Snowflake Tools Collection | Author: SE Community';
USE WAREHOUSE SFE_TOOLS_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
    COMMENT = 'Shared schema for semantic views across demo projects | Author: SE Community';

-- TOOLS schema hosts the DCM project object (separate from the schema it manages)
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.TOOLS
    COMMENT = 'Shared infrastructure for standalone tool projects | Author: SE Community';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
  COMMENT = 'Shared monorepo Git repository | Author: SE Community';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- ============================================================================
-- DCM: Create project object and deploy declarative definitions
-- Manages: DR_COST_AGENT schema, PRICING_CURRENT table, 3 views, grants
-- ============================================================================
USE ROLE SYSADMIN;

CREATE DCM PROJECT IF NOT EXISTS SNOWFLAKE_EXAMPLE.TOOLS.DCM_DR_COST
  COMMENT = 'DCM project for DR Cost Agent tool (Expires: 2026-05-01)';

EXECUTE DCM PROJECT SNOWFLAKE_EXAMPLE.TOOLS.DCM_DR_COST
  DEPLOY
FROM
  '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/dcm/';

-- ============================================================================
-- POST-HOOKS: Objects that DCM cannot manage (procedures, semantic view,
-- agent, data seeding, and their grants)
-- ============================================================================

-- Seed baseline pricing data (idempotent MERGE -- safe to re-run)
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/hooks/01_seed_pricing.sql';

-- Stored procedures (not yet supported by DCM DEFINE)
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/04_procedures/01_cost_projection.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/04_procedures/02_update_pricing.sql';

-- Semantic view (not yet supported by DCM DEFINE)
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/05_semantic/01_semantic_view.sql';

-- Agent (not yet supported by DCM DEFINE)
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/06_agent/01_agent.sql';

-- Grants for non-DCM objects + USAGE_VIEWER
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/hooks/02_post_dcm_grants.sql';

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    'DCM DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'DR Cost Agent (Snowflake Intelligence)' AS tool,
    '2026-05-01' AS expires,
    'DCM manages schema, table, views, grants; post-hooks handle procedures, agent, semantic view' AS architecture,
    'Open Snowflake Intelligence -> DR Cost Estimator' AS next_step;
