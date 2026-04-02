USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_COST_ANOMALIES
COMMENT = 'DEMO: Cortex Cost Intelligence - Week-over-week cost anomaly detection | See deploy_all.sql for expiration'
AS
WITH weekly_spend AS (
    SELECT
        DATE_TRUNC('week', usage_date)::DATE AS week_start,
        service_type,
        SUM(total_credits) AS weekly_credits
    FROM V_CORTEX_DAILY_SUMMARY
    GROUP BY DATE_TRUNC('week', usage_date), service_type
),
with_prev AS (
    SELECT
        week_start,
        service_type,
        weekly_credits,
        LAG(weekly_credits) OVER (
            PARTITION BY service_type ORDER BY week_start
        ) AS prev_week_credits
    FROM weekly_spend
)
SELECT
    week_start,
    service_type,
    ROUND(weekly_credits, 4)                                                        AS weekly_credits,
    ROUND(prev_week_credits, 4)                                                     AS prev_week_credits,
    ROUND(weekly_credits - COALESCE(prev_week_credits, 0), 4)                       AS absolute_change,
    CASE
        WHEN prev_week_credits > 0
        THEN ROUND((weekly_credits - prev_week_credits) / prev_week_credits, 4)
        ELSE NULL
    END                                                                              AS wow_growth_pct,
    CASE
        WHEN prev_week_credits > 0 AND (weekly_credits - prev_week_credits) / prev_week_credits >= 0.50
        THEN 'HIGH'
        WHEN prev_week_credits > 0 AND (weekly_credits - prev_week_credits) / prev_week_credits >= 0.25
        THEN 'MEDIUM'
        WHEN prev_week_credits > 0 AND (weekly_credits - prev_week_credits) / prev_week_credits >= 0.10
        THEN 'LOW'
        ELSE 'NORMAL'
    END                                                                              AS alert_severity
FROM with_prev
WHERE prev_week_credits IS NOT NULL
ORDER BY week_start DESC, alert_severity;

CREATE OR REPLACE VIEW V_COST_ANOMALIES_CURRENT
COMMENT = 'DEMO: Cortex Cost Intelligence - Active cost anomalies (MEDIUM+) | See deploy_all.sql for expiration'
AS
SELECT *
FROM V_COST_ANOMALIES
WHERE alert_severity IN ('HIGH', 'MEDIUM')
  AND week_start >= DATEADD('week', -4, CURRENT_DATE())
ORDER BY alert_severity, wow_growth_pct DESC;
