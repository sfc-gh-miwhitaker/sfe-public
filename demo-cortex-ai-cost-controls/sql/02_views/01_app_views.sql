/*==============================================================================
02_VIEWS — Curated APP views over SNOWFLAKE.ACCOUNT_USAGE (LIVE, read-only)
Cortex AI Cost Controls demo | Expires: 2026-07-24

These views normalize the inconsistent Cortex usage views into clean shapes the
Streamlit app reads. Credit column naming varies by source view (CREDITS /
TOKEN_CREDITS / CREDITS_USED) and is normalized to CREDITS here.

IMPORTANT column facts verified against ACCOUNT_USAGE:
  - CORTEX_AI_FUNCTIONS_USAGE_HISTORY exposes USER_ID (NUMBER), NOT USER_NAME.
    We resolve it to a name via ACCOUNT_USAGE.USERS.
  - CORTEX_ANALYST_USAGE_HISTORY uses USERNAME; all others use USER_NAME.
  - Document AI and Search daily views have no user column (user_name = NULL).
  - All views carry ~45-60 min latency. "Today"/"now" means "as last reported".
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS;
USE WAREHOUSE SFE_CORTEX_AI_COST_CONTROLS_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- V_AI_USAGE_UNIFIED — one row per (day, service, user) with normalized credits.
-- The workhorse for the Overview and Attribution pages. 90-day window.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_AI_USAGE_UNIFIED
  COMMENT = 'DEMO: Normalized Cortex AI usage across services (Expires: 2026-07-24)'
AS
WITH ai_functions AS (
    SELECT DATE(h.start_time) AS usage_day,
           'AI Functions'     AS service,
           u.name             AS user_name,
           h.credits          AS credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY h
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON u.user_id = h.user_id
    WHERE h.start_time >= DATEADD('day', -90, CURRENT_DATE())
),
agents AS (
    SELECT DATE(start_time), 'Cortex Agents', user_name, token_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
    WHERE start_time >= DATEADD('day', -90, CURRENT_DATE())
),
analyst AS (
    SELECT DATE(start_time), 'Cortex Analyst', username, credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
    WHERE start_time >= DATEADD('day', -90, CURRENT_DATE())
),
intelligence AS (
    SELECT DATE(start_time), 'Snowflake Intelligence', user_name, token_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
    WHERE start_time >= DATEADD('day', -90, CURRENT_DATE())
),
coco_cli AS (
    SELECT DATE(usage_time), 'CoCo CLI', user_name, token_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    WHERE usage_time >= DATEADD('day', -90, CURRENT_DATE())
),
coco_snowsight AS (
    SELECT DATE(usage_time), 'CoCo Snowsight', user_name, token_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
    WHERE usage_time >= DATEADD('day', -90, CURRENT_DATE())
),
search AS (
    SELECT DATE(usage_date), 'Cortex Search', CAST(NULL AS VARCHAR), credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
    WHERE usage_date >= DATEADD('day', -90, CURRENT_DATE())
),
document_ai AS (
    SELECT DATE(start_time), 'Document AI', CAST(NULL AS VARCHAR), credits_used
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY
    WHERE start_time >= DATEADD('day', -90, CURRENT_DATE())
)
SELECT usage_day, service, user_name, credits FROM ai_functions
UNION ALL SELECT * FROM agents
UNION ALL SELECT * FROM analyst
UNION ALL SELECT * FROM intelligence
UNION ALL SELECT * FROM coco_cli
UNION ALL SELECT * FROM coco_snowsight
UNION ALL SELECT * FROM search
UNION ALL SELECT * FROM document_ai;

-- ─────────────────────────────────────────────────────────────────────────────
-- V_AI_SPEND_DAILY — top-line AI_SERVICES daily spend from METERING_DAILY_HISTORY
-- This is the billed rollup; use it for the headline trend on the Overview page.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_AI_SPEND_DAILY
  COMMENT = 'DEMO: Daily AI_SERVICES credits (billed rollup) (Expires: 2026-07-24)'
AS
SELECT usage_date::DATE AS usage_day,
       credits_used,
       credits_billed
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'AI_SERVICES'
  AND usage_date >= DATEADD('day', -90, CURRENT_DATE());

-- ─────────────────────────────────────────────────────────────────────────────
-- V_AI_SERVICE_SUMMARY_30D — per-service rollup, last 30 days (Overview cards)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_AI_SERVICE_SUMMARY_30D
  COMMENT = 'DEMO: Per-service AI credit rollup, 30 days (Expires: 2026-07-24)'
AS
SELECT service,
       SUM(credits)                AS total_credits,
       COUNT(*)                    AS event_rows,
       COUNT(DISTINCT user_name)   AS distinct_users
FROM V_AI_USAGE_UNIFIED
WHERE usage_day >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY service;

-- ─────────────────────────────────────────────────────────────────────────────
-- V_AI_SPEND_BY_USER_30D — per-user rollup across all services, last 30 days
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_AI_SPEND_BY_USER_30D
  COMMENT = 'DEMO: Per-user AI credit rollup, 30 days (Expires: 2026-07-24)'
AS
SELECT COALESCE(user_name, '(unattributed)') AS user_name,
       SUM(credits)  AS total_credits,
       COUNT(*)      AS event_rows
FROM V_AI_USAGE_UNIFIED
WHERE usage_day >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY COALESCE(user_name, '(unattributed)');

-- ─────────────────────────────────────────────────────────────────────────────
-- V_AGENT_SPEND_30D — Cortex Agent spend by agent (always populated if agents
-- exist; the Attribution page's fallback when no cost-center tags are present).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_AGENT_SPEND_30D
  COMMENT = 'DEMO: Cortex Agent spend by agent, 30 days (Expires: 2026-07-24)'
AS
SELECT agent_database_name || '.' || agent_schema_name || '.' || agent_name AS agent_fqn,
       SUM(token_credits)        AS total_credits,
       COUNT(*)                  AS request_count,
       COUNT(DISTINCT user_name) AS distinct_users
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1;

-- ─────────────────────────────────────────────────────────────────────────────
-- V_AGENT_ATTRIBUTION — tag-based cost-center attribution for agents.
-- Filters the AGENT_TAGS array for a tag named COST_CENTER (matches tag_setup).
-- Empty until you apply COST_CENTER tags (tags only attribute forward).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_AGENT_ATTRIBUTION
  COMMENT = 'DEMO: Agent spend grouped by COST_CENTER tag, 30 days (Expires: 2026-07-24)'
AS
SELECT t.value:value::VARCHAR AS cost_center,
       h.agent_database_name || '.' || h.agent_schema_name || '.' || h.agent_name AS agent_fqn,
       SUM(h.token_credits)   AS total_credits,
       COUNT(*)               AS request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.agent_tags) t
WHERE h.start_time >= DATEADD('day', -30, CURRENT_DATE())
  AND t.value:name::VARCHAR = 'COST_CENTER'
GROUP BY 1, 2;

-- ─────────────────────────────────────────────────────────────────────────────
-- V_AI_FUNCTION_USAGE_TODAY_BY_USER — today's AI Function credits per user.
-- Feeds the Limits page: compares observed spend to the limits table.
-- USER_ID resolved to name via ACCOUNT_USAGE.USERS.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_AI_FUNCTION_USAGE_TODAY_BY_USER
  COMMENT = 'DEMO: Per-user AI Function credits since midnight (Expires: 2026-07-24)'
AS
SELECT COALESCE(u.name, 'USER_ID_' || h.user_id::VARCHAR) AS user_name,
       SUM(h.credits)     AS credits_today,
       COUNT(*)           AS calls_today,
       MAX(h.start_time)  AS last_call_at
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY h
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON u.user_id = h.user_id
WHERE h.start_time >= DATE_TRUNC('day', CURRENT_TIMESTAMP())
GROUP BY COALESCE(u.name, 'USER_ID_' || h.user_id::VARCHAR);

-- ─────────────────────────────────────────────────────────────────────────────
-- V_RUNAWAY_CANDIDATES — in-flight AI Function queries (IS_COMPLETED = FALSE).
-- The Runaway page applies the credit threshold; this exposes all in-flight
-- queries from the last 24h with credits consumed so far.
-- NOTE: view latency (up to 60 min) means only long-running queries appear here
-- while still cancellable — this is a safety net, not a real-time kill switch.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_RUNAWAY_CANDIDATES
  COMMENT = 'DEMO: In-flight AI Function queries and credits so far (Expires: 2026-07-24)'
AS
SELECT h.query_id,
       h.start_time,
       h.function_name,
       h.model_name,
       COALESCE(u.name, 'USER_ID_' || h.user_id::VARCHAR) AS user_name,
       h.credits AS credits_so_far,
       DATEDIFF('minute', h.start_time, CURRENT_TIMESTAMP()) AS minutes_running
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY h
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON u.user_id = h.user_id
WHERE h.is_completed = FALSE
  AND h.start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP());

SELECT 'APP views created' AS step_02_views;
