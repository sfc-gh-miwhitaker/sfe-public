/*==============================================================================
07 - Observability Queries (Ad-Hoc)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-07-06

Run these queries individually in Snowsight after using the demo.
This file is NOT part of deploy_all.sql -- it is a read-only reference.
==============================================================================*/

USE WAREHOUSE SFE_AGENT_MULTICONTEXT_WH;


-- ============================================================================
-- A. Recent agent:run calls -- credits, tokens, and model used
--    Source: ACCOUNT_USAGE (up to 45-minute latency)
--    Works for BOTH "with object" and "without object" calls.
-- ============================================================================

SELECT
    start_time,
    end_time,
    user_name,
    agent_name,                                    -- NULL for "without object" calls
    request_id,
    token_credits,
    tokens,
    DATEDIFF('ms', start_time, end_time)           AS latency_ms
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 50;


-- ============================================================================
-- B. Per-model token breakdown
--    LATERAL FLATTEN on TOKENS_GRANULAR shows input/output tokens by model
--    for each sub-request within an agent:run call.
-- ============================================================================

SELECT
    h.start_time,
    h.user_name,
    h.request_id,
    g.value:"request_id"::VARCHAR                  AS sub_request_id,
    svc.key                                        AS service_type,
    mdl.key                                        AS model_name,
    mdl.value:"input"::INT                         AS input_tokens,
    mdl.value:"cache_read_input"::INT              AS cache_read_tokens,
    mdl.value:"output"::INT                        AS output_tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY  h,
    LATERAL FLATTEN(input => h.tokens_granular)           g,
    LATERAL FLATTEN(input => g.value, MODE => 'OBJECT')   svc,
    LATERAL FLATTEN(input => svc.value, MODE => 'OBJECT') mdl
WHERE h.start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
    AND svc.key != 'start_time'
ORDER BY h.start_time DESC;


-- ============================================================================
-- C. Hourly credit aggregation -- cost monitoring over time
-- ============================================================================

SELECT
    DATE_TRUNC('hour', start_time)                 AS hour_start,
    COUNT(*)                                       AS request_count,
    SUM(token_credits)                             AS total_credits,
    SUM(tokens)                                    AS total_tokens,
    AVG(DATEDIFF('ms', start_time, end_time))      AS avg_latency_ms
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 1 DESC;


-- ============================================================================
-- D. Cortex Analyst request logs for this demo's semantic view
--    Shows questions asked, SQL generated, and whether verified queries were
--    used.  Scoped to this demo's semantic view only.
-- ============================================================================

SELECT
    timestamp,
    latest_question,
    generated_sql,
    response_status_code,
    request_id,
    user_id,
    warnings
FROM TABLE(
    SNOWFLAKE.LOCAL.CORTEX_ANALYST_REQUESTS(
        'SEMANTIC_VIEW',
        'SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AGENT_MULTICONTEXT_VIEWERSHIP'
    )
)
ORDER BY timestamp DESC
LIMIT 50;


-- ============================================================================
-- E. AI Observability events (if populated for your account)
--    This table stores traces for agent objects.  For "without object" calls
--    rows may or may not appear -- check your account.  Included here so you
--    can verify.
-- ============================================================================

SELECT
    timestamp,
    record,
    record_attributes,
    resource_attributes
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
WHERE timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY timestamp DESC
LIMIT 50;
