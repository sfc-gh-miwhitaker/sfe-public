USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_PROVISIONED_THROUGHPUT_DETAIL
COMMENT = 'DEMO: Cortex Cost Intelligence - Provisioned throughput usage | See deploy_all.sql for expiration'
AS
SELECT
    interval_start_time                     AS start_time,
    interval_end_time                       AS end_time,
    DATE_TRUNC('day', interval_start_time)::DATE AS usage_date,
    provisioned_throughput_id,
    ai_service,
    cloud_service_provider,
    model_name,
    term_start_date,
    term_end_date,
    'Provisioned Throughput'                AS service_type,
    ptu_count,
    ptu_credits                             AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_PROVISIONED_THROUGHPUT_USAGE_HISTORY
WHERE interval_start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());
