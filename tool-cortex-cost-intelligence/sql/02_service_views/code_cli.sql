USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_CODE_CLI_DETAIL
COMMENT = 'DEMO: Cortex Cost Intelligence - Cortex Code CLI usage (Feb 2026) | See deploy_all.sql for expiration'
AS
SELECT
    usage_time,
    DATE_TRUNC('day', usage_time)::DATE     AS usage_date,
    user_id,
    request_id,
    parent_request_id,
    'Cortex Code CLI'                       AS service_type,
    token_credits                           AS credits,
    tokens,
    tokens_granular,
    credits_granular
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());
