CREATE OR REPLACE VIEW V_USER_AGENT_SPEND
  COMMENT = 'TOOL: Per-user per-agent credit attribution (Expires: 2026-04-22)'
AS
SELECT
    user_name,
    COALESCE(agent_name, '(no agent object)')     AS agent_name,
    service_source,
    COUNT(DISTINCT request_id)                    AS total_requests,
    COUNT(DISTINCT usage_date)                    AS active_days,
    SUM(credits)                                  AS total_credits,
    SUM(tokens)                                   AS total_tokens,
    MIN(usage_date)                               AS first_use,
    MAX(usage_date)                               AS last_use
FROM V_AGENT_COMBINED
GROUP BY user_name, COALESCE(agent_name, '(no agent object)'), service_source;
