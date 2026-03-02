/*******************************************************************************
 * DEMO PROJECT: Cortex Cost Calculator - Cost Anomaly Detection
 *
 * AUTHOR: SE Community
 * CREATED: 2026-01-05
 * See deploy_all.sql for expiration (30 days)
 *
 * PURPOSE:
 *   Proactive anomaly detection for Cortex cost spikes.
 *   Identifies unusual week-over-week growth patterns with severity levels.
 *
 * DEPLOYMENT METHOD: Run after deploy_cortex_monitoring.sql
 *
 * ALERT LEVELS:
 *   - HIGH: Week-over-week growth > 50%
 *   - MEDIUM: Week-over-week growth > 25%
 *   - NORMAL: Growth <= 25%
 *   - DECLINING: Negative growth
 *
 * VERSION: 1.0
 * LAST UPDATED: 2026-02-18
 ******************************************************************************/

-- ===========================================================================
-- SETUP: USE CORTEX_USAGE SCHEMA
-- ===========================================================================

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- ===========================================================================
-- EXPIRATION CHECK (MANDATORY)
-- ===========================================================================
DECLARE
    demo_expired EXCEPTION (-20001, 'DEMO EXPIRED: Do not deploy. Fork the repository and update expiration + syntax.');
    expiration_date DATE := $demo_expiration_date::DATE;
BEGIN
    IF (CURRENT_DATE() > expiration_date) THEN
        RAISE demo_expired;
    END IF;
END;

-- ===========================================================================
-- CREATE ANOMALY DETECTION VIEW
-- ===========================================================================

CREATE OR REPLACE VIEW V_COST_ANOMALIES
COMMENT = 'DEMO: cortex-trail - Detect cost anomalies with week-over-week growth analysis | See deploy_all.sql for expiration'
AS
WITH daily_credits AS (
    SELECT
        usage_date AS date,
        service_type,
        total_credits,
        daily_unique_users,
        total_operations
    FROM V_CORTEX_DAILY_SUMMARY
    WHERE usage_date >= DATEADD('day', -90, CURRENT_DATE())
),
weekly_comparison AS (
    SELECT
        date,
        service_type,
        total_credits,
        daily_unique_users,
        total_operations,
        -- Get credits from 7 days ago
        LAG(total_credits, 7) OVER (PARTITION BY service_type ORDER BY date) AS credits_7d_ago,
        -- Get credits from 14 days ago for trend analysis
        LAG(total_credits, 14) OVER (PARTITION BY service_type ORDER BY date) AS credits_14d_ago,
        -- Calculate 7-day moving average
        AVG(total_credits) OVER (
            PARTITION BY service_type
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS credits_7d_avg
    FROM daily_credits
)
SELECT
    date,
    service_type,
    total_credits,
    credits_7d_ago,
    credits_14d_ago,
    credits_7d_avg,
    daily_unique_users,
    total_operations,

    -- Calculate week-over-week growth percentage
    CASE
        WHEN credits_7d_ago IS NULL OR credits_7d_ago = 0 THEN NULL
        ELSE ROUND(((total_credits - credits_7d_ago) / credits_7d_ago) * 100, 2)
    END AS wow_growth_pct,

    -- Calculate absolute change
    CASE
        WHEN credits_7d_ago IS NULL THEN NULL
        ELSE ROUND(total_credits - credits_7d_ago, 4)
    END AS wow_credits_change,

    -- Calculate 2-week trend
    CASE
        WHEN credits_14d_ago IS NULL OR credits_14d_ago = 0 THEN NULL
        ELSE ROUND(((total_credits - credits_14d_ago) / credits_14d_ago) * 100, 2)
    END AS two_week_growth_pct,

    -- Deviation from 7-day average
    CASE
        WHEN credits_7d_avg IS NULL OR credits_7d_avg = 0 THEN NULL
        ELSE ROUND(((total_credits - credits_7d_avg) / credits_7d_avg) * 100, 2)
    END AS deviation_from_avg_pct,

    -- Alert level classification
    CASE
        WHEN credits_7d_ago IS NULL THEN 'INSUFFICIENT_DATA'
        WHEN ((total_credits - credits_7d_ago) / NULLIF(credits_7d_ago, 0)) > 0.50 THEN 'HIGH'
        WHEN ((total_credits - credits_7d_ago) / NULLIF(credits_7d_ago, 0)) > 0.25 THEN 'MEDIUM'
        WHEN ((total_credits - credits_7d_ago) / NULLIF(credits_7d_ago, 0)) < 0 THEN 'DECLINING'
        ELSE 'NORMAL'
    END AS alert_level,

    -- Alert message
    CASE
        WHEN credits_7d_ago IS NULL THEN 'Insufficient historical data for comparison'
        WHEN ((total_credits - credits_7d_ago) / NULLIF(credits_7d_ago, 0)) > 0.50 THEN
            'HIGH ALERT: ' || service_type || ' credits increased ' ||
            ROUND(((total_credits - credits_7d_ago) / credits_7d_ago) * 100, 0) || '% vs last week'
        WHEN ((total_credits - credits_7d_ago) / NULLIF(credits_7d_ago, 0)) > 0.25 THEN
            'MEDIUM ALERT: ' || service_type || ' credits increased ' ||
            ROUND(((total_credits - credits_7d_ago) / credits_7d_ago) * 100, 0) || '% vs last week'
        WHEN ((total_credits - credits_7d_ago) / NULLIF(credits_7d_ago, 0)) < -0.25 THEN
            'DECLINING: ' || service_type || ' credits decreased ' ||
            ABS(ROUND(((total_credits - credits_7d_ago) / credits_7d_ago) * 100, 0)) || '% vs last week'
        ELSE 'NORMAL: No significant change detected'
    END AS alert_message,

    -- Recommended action
    CASE
        WHEN credits_7d_ago IS NULL THEN 'Continue monitoring - need more historical data'
        WHEN ((total_credits - credits_7d_ago) / NULLIF(credits_7d_ago, 0)) > 0.50 THEN
            'INVESTIGATE: Review query patterns and user activity for ' || service_type
        WHEN ((total_credits - credits_7d_ago) / NULLIF(credits_7d_ago, 0)) > 0.25 THEN
            'MONITOR: Track ' || service_type || ' usage closely over next few days'
        WHEN ((total_credits - credits_7d_ago) / NULLIF(credits_7d_ago, 0)) < -0.25 THEN
            'REVIEW: Check if decrease in ' || service_type || ' is expected'
        ELSE 'Continue normal monitoring'
    END AS recommended_action

FROM weekly_comparison
WHERE credits_7d_ago IS NOT NULL  -- Only show rows with comparison data
ORDER BY date DESC, alert_level DESC, wow_growth_pct DESC;

-- ===========================================================================
-- CREATE SUMMARY VIEW FOR CURRENT ALERTS
-- ===========================================================================

CREATE OR REPLACE VIEW V_COST_ANOMALIES_CURRENT
COMMENT = 'DEMO: cortex-trail - Current active cost anomalies (last 7 days) | See deploy_all.sql for expiration'
AS
SELECT
    date,
    service_type,
    total_credits,
    credits_7d_ago,
    wow_growth_pct,
    wow_credits_change,
    alert_level,
    alert_message,
    recommended_action,
    daily_unique_users,

    -- Priority score for sorting (higher = more urgent)
    CASE alert_level
        WHEN 'HIGH' THEN 3
        WHEN 'MEDIUM' THEN 2
        WHEN 'DECLINING' THEN 1
        ELSE 0
    END AS priority_score

FROM V_COST_ANOMALIES
WHERE date >= DATEADD('day', -7, CURRENT_DATE())
  AND alert_level IN ('HIGH', 'MEDIUM')
ORDER BY priority_score DESC, date DESC, wow_growth_pct DESC;

-- ===========================================================================
-- CREATE AGGREGATE ANOMALY SUMMARY
-- ===========================================================================

CREATE OR REPLACE VIEW V_COST_ANOMALY_SUMMARY
COMMENT = 'DEMO: cortex-trail - Aggregated anomaly statistics by alert level | See deploy_all.sql for expiration'
AS
SELECT
    alert_level,
    COUNT(*) AS alert_count,
    COUNT(DISTINCT service_type) AS affected_services,
    AVG(wow_growth_pct) AS avg_growth_pct,
    MAX(wow_growth_pct) AS max_growth_pct,
    SUM(wow_credits_change) AS total_credits_change,
    MIN(date) AS first_occurrence,
    MAX(date) AS last_occurrence,
    LISTAGG(DISTINCT service_type, ', ') AS services_list
FROM V_COST_ANOMALIES
WHERE date >= DATEADD('day', -30, CURRENT_DATE())
  AND alert_level IN ('HIGH', 'MEDIUM', 'DECLINING')
GROUP BY alert_level
ORDER BY
    CASE alert_level
        WHEN 'HIGH' THEN 1
        WHEN 'MEDIUM' THEN 2
        WHEN 'DECLINING' THEN 3
        ELSE 4
    END;

-- ===========================================================================
-- DEPLOYMENT VERIFICATION
-- ===========================================================================

-- Test view creation
SELECT
    'Anomaly detection views created successfully' AS status,
    COUNT(*) AS view_count
FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'CORTEX_USAGE'
  AND TABLE_NAME LIKE 'V_COST_ANOMALY%';

-- Show current anomalies (if any)
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'No active anomalies detected'
        ELSE COUNT(*) || ' active anomalies detected'
    END AS current_status
FROM V_COST_ANOMALIES_CURRENT;

-- Display recent anomalies
SELECT
    date,
    service_type,
    total_credits,
    credits_7d_ago,
    wow_growth_pct,
    alert_level,
    alert_message,
    recommended_action
FROM V_COST_ANOMALIES_CURRENT
ORDER BY date DESC, priority_score DESC, wow_growth_pct DESC
LIMIT 10;

-- Show summary statistics
SELECT
    alert_level,
    alert_count,
    affected_services,
    avg_growth_pct,
    max_growth_pct,
    total_credits_change,
    first_occurrence,
    last_occurrence,
    services_list
FROM V_COST_ANOMALY_SUMMARY
ORDER BY
    CASE alert_level
        WHEN 'HIGH' THEN 1
        WHEN 'MEDIUM' THEN 2
        WHEN 'DECLINING' THEN 3
        ELSE 4
    END;

/*******************************************************************************
 * USAGE EXAMPLES
 ******************************************************************************/

-- Example 1: View all anomalies for last 30 days
-- SELECT anomaly_date, service_type, cost_usd, z_score FROM V_COST_ANOMALIES
-- WHERE date >= DATEADD('day', -30, CURRENT_DATE())
-- ORDER BY alert_level DESC, wow_growth_pct DESC;

-- Example 2: Get only HIGH alerts
-- SELECT date, service_type, wow_growth_pct, alert_message
-- FROM V_COST_ANOMALIES_CURRENT
-- WHERE alert_level = 'HIGH';

-- Example 3: Track specific service anomalies
-- SELECT date, total_credits, wow_growth_pct, alert_level
-- FROM V_COST_ANOMALIES
-- WHERE service_type = 'Cortex Functions'
-- ORDER BY date DESC;

-- Example 4: Create email alert (with SNOWFLAKE.CORTEX.COMPLETE)
-- SELECT SNOWFLAKE.CORTEX.COMPLETE(
--     'mistral-large2',
--     'Generate an email alert for these cost anomalies: ' ||
--     (SELECT LISTAGG(alert_message, '; ') FROM V_COST_ANOMALIES_CURRENT)
-- ) AS alert_email;
