USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_AI_FUNCTIONS_DETAIL
COMMENT = 'DEMO: Cortex Cost Intelligence - AI Functions granular usage (GA Mar 2026) | See deploy_all.sql for expiration'
AS
SELECT
    start_time,
    end_time,
    DATE_TRUNC('day', start_time)::DATE AS usage_date,
    function_name,
    model_name,
    query_id,
    warehouse_id,
    role_names,
    query_tag,
    user_id,
    'Cortex AI Functions'               AS service_type,
    credits,
    is_completed,
    metrics
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());
