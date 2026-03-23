CREATE OR REPLACE VIEW V_AGENT_COMBINED
  COMMENT = 'TOOL: Combined Cortex Agent + Snowflake Intelligence usage (Expires: 2026-04-22)'
AS
SELECT
    start_time,
    end_time,
    usage_date,
    latency_ms,
    user_name,
    request_id,
    parent_request_id,
    agent_database_name,
    agent_schema_name,
    agent_name,
    NULL                                          AS snowflake_intelligence_name,
    service_source,
    credits,
    tokens,
    tokens_granular,
    credits_granular
FROM V_AGENT_DETAIL

UNION ALL

SELECT
    start_time,
    end_time,
    usage_date,
    latency_ms,
    user_name,
    request_id,
    parent_request_id,
    agent_database_name,
    agent_schema_name,
    agent_name,
    snowflake_intelligence_name,
    service_source,
    credits,
    tokens,
    tokens_granular,
    credits_granular
FROM V_INTELLIGENCE_DETAIL;
