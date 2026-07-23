-- =============================================================================
-- CORTEX AI VISIBILITY QUERIES
-- Run as: ACCOUNTADMIN (or any role with IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE)
-- Purpose: Query every Cortex AI usage view to understand where credits are going.
-- Latency: ACCOUNT_USAGE views have ~45 minute latency from event to availability.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. OVERALL AI SERVICES ROLLUP (high-level starting point)
-- Use: "How many AI credits did we burn this month?"
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    usage_date,
    service_type,
    credits_used,
    credits_billed
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'AI_SERVICES'
  AND usage_date >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY usage_date DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. CORTEX AI FUNCTIONS (AI_CLASSIFY, AI_COMPLETE, AI_EXTRACT, etc.)
-- Credit column: CREDITS
-- Key for runaway detection: IS_COMPLETED = FALSE means still running
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    start_time,
    function_name,
    model_name,
    query_id,
    user_id,
    credits,
    is_completed
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY credits DESC
LIMIT 100;

-- Summary by function and model
SELECT
    function_name,
    model_name,
    COUNT(*) AS invocation_count,
    SUM(credits) AS total_credits,
    AVG(credits) AS avg_credits_per_call
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY function_name, model_name
ORDER BY total_credits DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. CORTEX AGENTS
-- Credit column: TOKEN_CREDITS
-- Tags: AGENT_TAGS array and USER_TAGS array (for tag-based attribution)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    start_time,
    user_name,
    agent_database_name,
    agent_schema_name,
    agent_name,
    token_credits,
    tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY token_credits DESC
LIMIT 100;

-- Summary by agent
SELECT
    agent_database_name || '.' || agent_schema_name || '.' || agent_name AS agent_fqn,
    COUNT(*) AS request_count,
    SUM(token_credits) AS total_credits,
    COUNT(DISTINCT user_name) AS distinct_users
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY agent_fqn
ORDER BY total_credits DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. CORTEX ANALYST (text-to-SQL)
-- Credit column: CREDITS
-- Note: uses USERNAME (not USER_NAME) — this is the only view with this naming
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    start_time,
    end_time,
    username,
    credits,
    request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY credits DESC
LIMIT 100;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. SNOWFLAKE INTELLIGENCE (CoWork)
-- Credit column: TOKEN_CREDITS
-- Also tracks which underlying agent handled the request
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    start_time,
    user_name,
    snowflake_intelligence_name,
    agent_name,
    token_credits,
    tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY token_credits DESC
LIMIT 100;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. CORTEX CODE CLI
-- Credit column: TOKEN_CREDITS
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    usage_time,
    user_name,
    token_credits,
    tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY token_credits DESC
LIMIT 100;

-- Summary by user (who's using CoCo CLI the most?)
SELECT
    user_name,
    COUNT(*) AS session_count,
    SUM(token_credits) AS total_credits,
    SUM(tokens) AS total_tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY user_name
ORDER BY total_credits DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. CORTEX CODE SNOWSIGHT
-- Credit column: TOKEN_CREDITS
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    usage_time,
    user_name,
    token_credits,
    tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY token_credits DESC
LIMIT 100;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. CORTEX SEARCH (daily aggregated)
-- Credit column: CREDITS
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    usage_date,
    database_name,
    schema_name,
    service_name,
    consumption_type,
    credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY credits DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. CORTEX SEARCH SERVING (per-query)
-- Credit column: CREDITS
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    start_time,
    database_name,
    schema_name,
    service_name,
    credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_SERVING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY credits DESC
LIMIT 100;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. CORTEX SEARCH BATCH QUERIES
-- Credit column: CREDITS_USED
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    start_time,
    database_name,
    schema_name,
    service_name,
    consumption_type,
    credits_used,
    model_name,
    tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_BATCH_QUERY_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY credits_used DESC
LIMIT 100;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. DOCUMENT AI / AI_PARSE_DOCUMENT
-- Credit column: CREDITS_USED
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    start_time,
    function_name,
    model_name,
    operation_name,
    page_count,
    document_count,
    credits_used
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY credits_used DESC
LIMIT 100;

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. CORTEX FINE-TUNING
-- Credit column: TOKEN_CREDITS
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    start_time,
    end_time,
    model_name,
    token_credits,
    tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FINE_TUNING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY token_credits DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. CORTEX REST API
-- Credit column: (uses TOKENS — check if credits column available)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    start_time,
    end_time,
    request_id,
    model_name,
    tokens,
    user_id,
    inference_region,
    query_tag
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY tokens DESC
LIMIT 100;

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. CORTEX PROVISIONED THROUGHPUT
-- Credit column: PTU_CREDITS
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    interval_start_time,
    interval_end_time,
    cloud_service_provider,
    model_name,
    term_start_date,
    term_end_date,
    ptu_count,
    ptu_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_PROVISIONED_THROUGHPUT_USAGE_HISTORY
WHERE interval_start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY ptu_credits DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- BONUS: Cross-service summary (last 30 days)
-- Combines data from all credit-bearing views into one report
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'AI Functions' AS service, SUM(credits) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
UNION ALL
SELECT 'Cortex Agents', SUM(token_credits)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
UNION ALL
SELECT 'Cortex Analyst', SUM(credits)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
UNION ALL
SELECT 'Snowflake Intelligence', SUM(token_credits)
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
UNION ALL
SELECT 'CoCo CLI', SUM(token_credits)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -30, CURRENT_DATE())
UNION ALL
SELECT 'CoCo Snowsight', SUM(token_credits)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -30, CURRENT_DATE())
UNION ALL
SELECT 'Cortex Search', SUM(credits)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
UNION ALL
SELECT 'Document AI', SUM(credits_used)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
UNION ALL
SELECT 'Fine-Tuning', SUM(token_credits)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FINE_TUNING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
UNION ALL
SELECT 'Provisioned Throughput', SUM(ptu_credits)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_PROVISIONED_THROUGHPUT_USAGE_HISTORY
WHERE interval_start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY total_credits DESC;
