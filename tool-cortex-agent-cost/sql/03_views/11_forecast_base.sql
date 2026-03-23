CREATE OR REPLACE VIEW V_FORECAST_BASE
  COMMENT = 'TOOL: Daily credit totals for trend analysis and forecasting (Expires: 2026-04-22)'
AS
SELECT
    usage_date,
    SUM(credits)                                  AS daily_credits,
    SUM(tokens)                                   AS daily_tokens,
    COUNT(DISTINCT request_id)                    AS daily_requests,
    COUNT(DISTINCT user_name)                     AS daily_users,
    COUNT(DISTINCT COALESCE(agent_name, '(none)')) AS daily_agents
FROM V_AGENT_COMBINED
WHERE usage_date < CURRENT_DATE()
GROUP BY usage_date
ORDER BY usage_date;
