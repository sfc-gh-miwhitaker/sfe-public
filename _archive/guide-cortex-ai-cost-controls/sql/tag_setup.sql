-- =============================================================================
-- TAG-BASED COST ATTRIBUTION
-- Run as: ACCOUNTADMIN (or a role with CREATE TAG privileges)
-- Purpose: Set up tags to attribute Cortex AI costs to teams, projects, or cost centers.
--
-- How tags work for cost attribution:
-- 1. Create a tag (e.g., cost_center)
-- 2. Apply it to the objects that generate cost (agents, warehouses, users)
-- 3. Query usage views that include *_TAGS columns to group spend by tag value
--
-- Important: Tags only attribute spend FORWARD from the moment applied.
-- Historical usage before the tag was set is unattributed.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Create a tag for cost attribution
-- ─────────────────────────────────────────────────────────────────────────────

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS COST_GOVERNANCE;
CREATE SCHEMA IF NOT EXISTS COST_GOVERNANCE.TAGS;

CREATE TAG IF NOT EXISTS COST_GOVERNANCE.TAGS.COST_CENTER
  COMMENT = 'Identifies the team or project that owns this cost';

CREATE TAG IF NOT EXISTS COST_GOVERNANCE.TAGS.ENVIRONMENT
  COMMENT = 'dev, staging, or prod — useful for filtering non-production noise';

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Apply tags to Cortex objects
-- ─────────────────────────────────────────────────────────────────────────────

-- Tag a Cortex Agent
ALTER AGENT my_db.my_schema.sales_agent
  SET TAG COST_GOVERNANCE.TAGS.COST_CENTER = 'sales_team';

ALTER AGENT my_db.my_schema.support_agent
  SET TAG COST_GOVERNANCE.TAGS.COST_CENTER = 'support_team';

ALTER AGENT my_db.my_schema.finance_agent
  SET TAG COST_GOVERNANCE.TAGS.COST_CENTER = 'finance_team';

-- Tag a warehouse used by agents
ALTER WAREHOUSE agent_wh
  SET TAG COST_GOVERNANCE.TAGS.COST_CENTER = 'shared_ai';

-- Tag users by team
ALTER USER alice SET TAG COST_GOVERNANCE.TAGS.COST_CENTER = 'sales_team';
ALTER USER bob   SET TAG COST_GOVERNANCE.TAGS.COST_CENTER = 'support_team';
ALTER USER carol SET TAG COST_GOVERNANCE.TAGS.COST_CENTER = 'finance_team';

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Query usage grouped by tag
-- These views include AGENT_TAGS and USER_TAGS columns as ARRAYs of objects.
--
-- INSPECT FIRST. The exact key names inside each array element vary, so before
-- writing attribution queries, look at the actual shape on YOUR account:
--
--   SELECT agent_tags FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
--   WHERE ARRAY_SIZE(agent_tags) > 0 LIMIT 5;
--
-- Then adjust the t.value:name / t.value:value paths below to match what you see.
-- FLATTEN is used (instead of positional [0] access) so attribution still works
-- when an object carries more than one tag.
-- ─────────────────────────────────────────────────────────────────────────────

-- Cortex Agent spend by cost center (FLATTEN over AGENT_TAGS)
SELECT
    h.agent_name,
    t.value:value::VARCHAR AS cost_center,
    SUM(h.token_credits) AS total_credits,
    COUNT(*) AS request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.agent_tags) t
WHERE h.start_time >= DATEADD('day', -30, CURRENT_DATE())
  AND t.value:name::VARCHAR = 'COST_CENTER'
GROUP BY h.agent_name, cost_center
ORDER BY total_credits DESC;

-- Spend by user cost center (FLATTEN over USER_TAGS)
SELECT
    h.user_name,
    t.value:value::VARCHAR AS cost_center,
    SUM(h.token_credits) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.user_tags) t
WHERE h.start_time >= DATEADD('day', -30, CURRENT_DATE())
  AND t.value:name::VARCHAR = 'COST_CENTER'
GROUP BY h.user_name, cost_center
ORDER BY total_credits DESC;

-- Snowflake Intelligence spend by cost center
SELECT
    h.user_name,
    h.snowflake_intelligence_name,
    t.value:value::VARCHAR AS cost_center,
    SUM(h.token_credits) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.user_tags) t
WHERE h.start_time >= DATEADD('day', -30, CURRENT_DATE())
  AND t.value:name::VARCHAR = 'COST_CENTER'
GROUP BY h.user_name, h.snowflake_intelligence_name, cost_center
ORDER BY total_credits DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Verify tags using TAG_REFERENCES view
-- (Confirm your tags are actually applied where you think they are)
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    object_database,
    object_schema,
    object_name,
    domain,
    tag_name,
    tag_value
FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
WHERE tag_name = 'COST_CENTER'
  AND tag_schema = 'TAGS'
  AND tag_database = 'COST_GOVERNANCE'
ORDER BY domain, object_name;
