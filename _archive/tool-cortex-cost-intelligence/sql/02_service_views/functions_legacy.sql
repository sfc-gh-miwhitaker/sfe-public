USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_FUNCTIONS_DETAIL
COMMENT = 'DEMO: Cortex Cost Intelligence - Legacy Cortex Functions usage | See deploy_all.sql for expiration'
AS
SELECT
    start_time,
    end_time,
    DATE_TRUNC('day', start_time)::DATE AS usage_date,
    function_name,
    model_name,
    warehouse_id,
    'Cortex Functions (Legacy)'         AS service_type,
    token_credits                       AS credits,
    tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());
