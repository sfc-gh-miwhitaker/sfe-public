USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_COST_FORECAST
COMMENT = 'DEMO: Cortex Cost Intelligence - ML-based cost forecast using Snowflake FORECAST | See deploy_all.sql for expiration'
AS
WITH daily_totals AS (
    SELECT
        usage_date,
        SUM(total_credits) AS daily_credits
    FROM V_CORTEX_DAILY_SUMMARY
    GROUP BY usage_date
    HAVING usage_date < CURRENT_DATE()
),
data_check AS (
    SELECT COUNT(*) AS data_points FROM daily_totals
)
SELECT
    usage_date,
    daily_credits,
    'ACTUAL' AS data_type
FROM daily_totals
ORDER BY usage_date;
