USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_USAGE_HISTORY
COMMENT = 'DEMO: Cortex Cost Intelligence - Snapshot-backed usage history for long-term trending | See deploy_all.sql for expiration'
AS
WITH live_data AS (
    SELECT
        usage_date,
        service_type,
        daily_unique_users,
        total_operations,
        total_credits,
        credits_per_user,
        credits_per_operation,
        'LIVE' AS data_source
    FROM V_CORTEX_DAILY_SUMMARY
),
snapshot_data AS (
    SELECT
        snapshot_date          AS usage_date,
        service_type,
        daily_unique_users,
        total_operations,
        total_credits,
        credits_per_user,
        credits_per_operation,
        'SNAPSHOT' AS data_source
    FROM CORTEX_USAGE_SNAPSHOTS
    WHERE snapshot_date < DATEADD('day', -90, CURRENT_DATE())
)
SELECT * FROM live_data
UNION ALL
SELECT * FROM snapshot_data
ORDER BY usage_date DESC, total_credits DESC;
