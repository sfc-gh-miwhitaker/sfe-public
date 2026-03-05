/******************************************************************************
 * Tool: DR Cost Agent (Snowflake Intelligence)
 * File: deploy.sql
 * Author: SE Community
 * Created: 2025-12-08
 * Last Updated: 2026-03-04
 * Expires: 2026-05-01
 *
 * Prerequisites:
 *   1. Run shared/sql/00_shared_setup.sql once (creates SNOWFLAKE_EXAMPLE + SFE_TOOLS_WH)
 *   2. SYSADMIN role access (ACCOUNTADMIN only for USAGE_VIEWER grant)
 *
 * How to Deploy:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 *
 * What This Creates:
 *   - Schema: SNOWFLAKE_EXAMPLE.DR_COST_AGENT
 *   - Table: PRICING_CURRENT (60 baseline pricing rows)
 *   - Views: DB_METADATA_V2, HYBRID_TABLE_METADATA, REPLICATION_HISTORY
 *   - Procedure: COST_PROJECTION (custom tool for agent)
 *   - Semantic View: SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST
 *   - Agent: DR_COST_AGENT (Snowflake Intelligence)
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (Informational -- warns but does not block deployment)
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
-- FETCH LATEST CODE (monorepo Git integration)
-- ============================================================================
USE ROLE SYSADMIN;
ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- ============================================================================
-- EXECUTE SCRIPTS IN ORDER
-- ============================================================================
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/01_setup/01_schema_and_warehouse.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/02_tables/01_pricing_current.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/03_views/01_db_metadata_v2.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/03_views/02_hybrid_table_metadata.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/03_views/03_replication_history.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/04_procedures/01_cost_projection.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/05_semantic/01_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/06_agent/01_agent.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-dr-cost-agent/sql/99_grants/01_grants.sql';

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    'DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'DR Cost Agent (Snowflake Intelligence)' AS tool,
    '2026-05-01' AS expires,
    'Open Snowflake Intelligence -> DR Cost Estimator' AS next_step;
