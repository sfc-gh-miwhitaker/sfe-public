USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_SNOWFLAKE_INTELLIGENCE_DETAIL
COMMENT = 'DEMO: Cortex Cost Intelligence - Snowflake Intelligence app usage (Feb 2026) | See deploy_all.sql for expiration'
AS
SELECT
    start_time,
    end_time,
    DATE_TRUNC('day', start_time)::DATE     AS usage_date,
    user_id,
    user_name,
    request_id,
    snowflake_intelligence_id,
    snowflake_intelligence_name,
    agent_database_name,
    agent_schema_name,
    agent_id,
    agent_name,
    'Snowflake Intelligence'                AS service_type,
    token_credits                           AS credits,
    tokens,
    tokens_granular,
    credits_granular,
    metadata
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());
