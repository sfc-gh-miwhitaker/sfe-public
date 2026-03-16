/*==============================================================================
DEPLOY ALL - GitHub-Powered Project Tooling for Cortex Code
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-15
INSTRUCTIONS: Open in Snowsight -> Click "Run All"
==============================================================================*/

/*******************************************************************************
 * DEMO METADATA (Machine-readable - Do not modify format)
 * PROJECT_NAME: coco-governance-github
 * AUTHOR: SE Community
 * CREATED: 2026-03-16
 * EXPIRES: 2026-04-15
 * GITHUB_REPO: sfe-public
 * PURPOSE: Show how AGENTS.md and skills in a GitHub repo deliver consistent
 *          Cortex Code standards across CLI and Snowsight workspaces
 *
 * PREREQUISITES:
 * - ACCOUNTADMIN role access
 * - Cortex Code enabled in your account
 *
 * WARNING: NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (informational - warns but does not block)
-- ============================================================================

SELECT
    TO_DATE('2026-04-15') AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-04-15')) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-04-15')) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Remove expiration banner to continue.'
        WHEN DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-04-15')) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-04-15')) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-04-15')) || ' days remaining'
    END AS demo_status;

-- ============================================================================
-- 1. SETUP CONTEXT
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- 2. SHARED INFRASTRUCTURE (idempotent - safe to re-run)
-- ============================================================================

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
    ENABLED = TRUE
    COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION (Expires: 2026-04-15)';

-- ============================================================================
-- 3. GIT REPOSITORY (enables Snowsight workspace connection)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
    COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
    API_INTEGRATION = SFE_GIT_API_INTEGRATION
    ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
    COMMENT = 'Shared monorepo Git repository | Author: SE Community';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- ============================================================================
-- 4. EXECUTE SETUP (schema, warehouse, sample tables with seed data)
-- ============================================================================

EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-coco-governance-github/sql/01_setup/01_create_demo_objects.sql';

-- ============================================================================
-- 5. DEPLOYMENT SUMMARY
-- ============================================================================

SELECT
    'Deployment complete!' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB' AS schema_created,
    'Try: ask Cortex Code to write a query against the ORDERS table' AS next_step;
