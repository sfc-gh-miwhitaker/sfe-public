USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_COST_EXPORT
COMMENT = 'DEMO: Cortex Cost Intelligence - Cross-referenced with METERING_DAILY_HISTORY for total AI_SERVICES spend | See deploy_all.sql for expiration'
AS
WITH detail_summary AS (
    SELECT
        usage_date,
        SUM(total_credits) AS detail_credits
    FROM V_CORTEX_DAILY_SUMMARY
    GROUP BY usage_date
),
metering AS (
    SELECT
        usage_date,
        credits_used_compute,
        credits_used_cloud_services,
        credits_used,
        credits_billed
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE service_type = 'AI_SERVICES'
      AND usage_date >= DATEADD('day', -90, CURRENT_DATE())
)
SELECT
    COALESCE(d.usage_date, m.usage_date)                    AS usage_date,
    d.detail_credits,
    m.credits_used                                           AS metering_credits_used,
    m.credits_billed                                         AS metering_credits_billed,
    m.credits_used_compute,
    m.credits_used_cloud_services,
    ROUND(d.detail_credits - COALESCE(m.credits_used, 0), 6) AS variance_detail_vs_metering
FROM detail_summary d
FULL OUTER JOIN metering m ON d.usage_date = m.usage_date
ORDER BY COALESCE(d.usage_date, m.usage_date) DESC;
