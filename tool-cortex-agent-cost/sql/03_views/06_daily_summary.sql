CREATE OR REPLACE VIEW V_DAILY_SUMMARY
  COMMENT = 'TOOL: Daily aggregation by agent, user, and service source (Expires: 2026-04-22)'
AS
SELECT
    usage_date,
    service_source,
    COALESCE(agent_name, '(no agent object)')     AS agent_name,
    user_name,
    COUNT(DISTINCT request_id)                    AS request_count,
    SUM(credits)                                  AS total_credits,
    SUM(tokens)                                   AS total_tokens,
    AVG(latency_ms)                               AS avg_latency_ms,
    COUNT(DISTINCT CASE
        WHEN parent_request_id IS NOT NULL
        THEN request_id
    END)                                          AS child_request_count
FROM V_AGENT_COMBINED
GROUP BY usage_date, service_source, COALESCE(agent_name, '(no agent object)'), user_name;
