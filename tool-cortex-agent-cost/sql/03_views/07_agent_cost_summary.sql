CREATE OR REPLACE VIEW V_AGENT_COST_SUMMARY
  COMMENT = 'TOOL: Per-agent cost totals, token counts, and latency (Expires: 2026-04-22)'
AS
SELECT
    COALESCE(agent_name, '(no agent object)')     AS agent_name,
    service_source,
    agent_database_name,
    agent_schema_name,
    COUNT(DISTINCT request_id)                    AS total_requests,
    COUNT(DISTINCT user_name)                     AS unique_users,
    COUNT(DISTINCT usage_date)                    AS active_days,
    SUM(credits)                                  AS total_credits,
    SUM(tokens)                                   AS total_tokens,
    AVG(latency_ms)                               AS avg_latency_ms,
    MEDIAN(latency_ms)                            AS p50_latency_ms,
    MIN(usage_date)                               AS first_use,
    MAX(usage_date)                               AS last_use
FROM V_AGENT_COMBINED
GROUP BY COALESCE(agent_name, '(no agent object)'), service_source,
         agent_database_name, agent_schema_name;
