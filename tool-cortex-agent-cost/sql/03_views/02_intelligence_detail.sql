CREATE OR REPLACE VIEW V_INTELLIGENCE_DETAIL
  COMMENT = 'TOOL: Snowflake Intelligence usage detail — 90-day window (Expires: 2026-04-22)'
AS
SELECT
    start_time,
    end_time,
    DATE_TRUNC('day', start_time)::DATE          AS usage_date,
    DATEDIFF('ms', start_time, end_time)          AS latency_ms,
    user_name,
    request_id,
    parent_request_id,
    agent_database_name,
    agent_schema_name,
    agent_name,
    snowflake_intelligence_name,
    'Snowflake Intelligence'                      AS service_source,
    token_credits                                 AS credits,
    tokens,
    tokens_granular,
    credits_granular,
    metadata
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());
