USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_REST_API_DETAIL
COMMENT = 'DEMO: Cortex Cost Intelligence - REST API usage (billed in USD, not credits) | See deploy_all.sql for expiration'
AS
SELECT
    start_time,
    end_time,
    DATE_TRUNC('day', start_time)::DATE AS usage_date,
    request_id,
    model_name,
    user_id,
    inference_region,
    'Cortex REST API'                           AS service_type,
    tokens,
    tokens_granular,
    tokens_granular:"input"::NUMBER             AS tokens_input,
    tokens_granular:"output"::NUMBER            AS tokens_output
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());
