/*==============================================================================
DEPLOY ALL - Governed GitHub Integration for Cortex Code
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
 * PURPOSE: Governed GitHub MCP integration with progressive unlock pattern
 *
 * PREREQUISITES:
 * - ACCOUNTADMIN role access
 * - Cortex AI enabled in your account
 * - GitHub PAT or 1Password CLI (for MCP configuration)
 * - Completed general governance workshop (recommended)
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
-- 3. CREATE SCHEMA + WAREHOUSE
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB
    COMMENT = 'DEMO: coco-governance-github - Governed GitHub MCP integration for Cortex Code (Expires: 2026-04-15)';

CREATE WAREHOUSE IF NOT EXISTS SFE_COCO_GOVERNANCE_GITHUB_WH WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'DEMO: coco-governance-github - Compute for governance advisor queries (Expires: 2026-04-15)';

-- ============================================================================
-- 4. GIT REPOSITORY
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
    COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
    API_INTEGRATION = SFE_GIT_API_INTEGRATION
    ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
    COMMENT = 'Shared monorepo Git repository | Author: SE Community';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- ============================================================================
-- 5. EXECUTE SETUP SCRIPTS
-- ============================================================================

EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-coco-governance-github/sql/01_setup/01_create_demo_objects.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-coco-governance-github/sql/01_setup/02_create_audit_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-coco-governance-github/sql/01_setup/04_create_policy_check_function.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-coco-governance-github/sql/01_setup/03_create_governance_advisor.sql';

-- ============================================================================
-- 6. DEPLOYMENT SUMMARY
-- ============================================================================

SELECT
    'Deployment complete!' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Ask GOVERNANCE_ADVISOR: Am I ready to enable GitHub?' AS next_step;
