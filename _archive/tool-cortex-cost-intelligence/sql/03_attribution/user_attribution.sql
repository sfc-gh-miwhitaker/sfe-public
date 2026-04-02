USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_USER_SPEND_ATTRIBUTION
COMMENT = 'DEMO: Cortex Cost Intelligence - User-level spend attribution across all services | See deploy_all.sql for expiration'
AS
WITH analyst_users AS (
    SELECT
        usage_date,
        user_name,
        'Cortex Analyst'   AS service_type,
        NULL               AS model_name,
        NULL               AS function_name,
        credits,
        operations
    FROM V_CORTEX_ANALYST_DETAIL
),
ai_functions_users AS (
    SELECT
        usage_date,
        u.name              AS user_name,
        'Cortex AI Functions' AS service_type,
        f.model_name,
        f.function_name,
        SUM(f.credits)      AS credits,
        COUNT(f.query_id)   AS operations
    FROM V_CORTEX_AI_FUNCTIONS_DETAIL f
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
        ON f.user_id = u.user_id
    GROUP BY f.usage_date, u.name, f.model_name, f.function_name
),
agent_users AS (
    SELECT
        usage_date,
        user_name,
        'Cortex Agent'     AS service_type,
        NULL               AS model_name,
        agent_name         AS function_name,
        SUM(credits)       AS credits,
        COUNT(request_id)  AS operations
    FROM V_CORTEX_AGENT_DETAIL
    GROUP BY usage_date, user_name, agent_name
),
intelligence_users AS (
    SELECT
        usage_date,
        user_name,
        'Snowflake Intelligence' AS service_type,
        NULL               AS model_name,
        snowflake_intelligence_name AS function_name,
        SUM(credits)       AS credits,
        COUNT(request_id)  AS operations
    FROM V_SNOWFLAKE_INTELLIGENCE_DETAIL
    GROUP BY usage_date, user_name, snowflake_intelligence_name
),
all_users AS (
    SELECT usage_date, user_name, service_type, model_name, function_name, credits, operations FROM analyst_users
    UNION ALL
    SELECT usage_date, user_name, service_type, model_name, function_name, credits, operations FROM ai_functions_users
    UNION ALL
    SELECT usage_date, user_name, service_type, model_name, function_name, credits, operations FROM agent_users
    UNION ALL
    SELECT usage_date, user_name, service_type, model_name, function_name, credits, operations FROM intelligence_users
)
SELECT
    usage_date,
    user_name,
    service_type,
    model_name,
    function_name,
    credits                                                              AS credits_used,
    operations,
    CASE WHEN operations > 0 THEN ROUND(credits / operations, 6) ELSE 0 END AS credits_per_operation
FROM all_users
WHERE user_name IS NOT NULL;
