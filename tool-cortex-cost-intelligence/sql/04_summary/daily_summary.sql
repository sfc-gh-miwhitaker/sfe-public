USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_DAILY_SUMMARY
COMMENT = 'DEMO: Cortex Cost Intelligence - Daily summary across all Cortex services | See deploy_all.sql for expiration'
AS
WITH analyst AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_name) AS daily_unique_users, SUM(operations) AS total_operations, SUM(credits) AS total_credits
    FROM V_CORTEX_ANALYST_DETAIL GROUP BY usage_date, service_type
),
ai_functions AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_id) AS daily_unique_users, COUNT(query_id) AS total_operations, SUM(credits) AS total_credits
    FROM V_CORTEX_AI_FUNCTIONS_DETAIL GROUP BY usage_date, service_type
),
search AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits
    FROM V_CORTEX_SEARCH_DETAIL GROUP BY usage_date, service_type
),
search_serving AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits
    FROM V_CORTEX_SEARCH_SERVING_DETAIL GROUP BY usage_date, service_type
),
agent AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_name) AS daily_unique_users, COUNT(request_id) AS total_operations, SUM(credits) AS total_credits
    FROM V_CORTEX_AGENT_DETAIL GROUP BY usage_date, service_type
),
intelligence AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_name) AS daily_unique_users, COUNT(request_id) AS total_operations, SUM(credits) AS total_credits
    FROM V_SNOWFLAKE_INTELLIGENCE_DETAIL GROUP BY usage_date, service_type
),
code_cli AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_id) AS daily_unique_users, COUNT(request_id) AS total_operations, SUM(credits) AS total_credits
    FROM V_CORTEX_CODE_CLI_DETAIL GROUP BY usage_date, service_type
),
fine_tuning AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits
    FROM V_CORTEX_FINE_TUNING_DETAIL GROUP BY usage_date, service_type
),
doc_processing AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(query_id) AS total_operations, SUM(credits) AS total_credits
    FROM V_CORTEX_DOCUMENT_PROCESSING_DETAIL GROUP BY usage_date, service_type
),
rest_api AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_id) AS daily_unique_users, COUNT(request_id) AS total_operations, 0::NUMBER(38,6) AS total_credits
    FROM V_CORTEX_REST_API_DETAIL GROUP BY usage_date, service_type
),
legacy_functions AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits
    FROM V_CORTEX_FUNCTIONS_DETAIL GROUP BY usage_date, service_type
),
provisioned AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits
    FROM V_CORTEX_PROVISIONED_THROUGHPUT_DETAIL GROUP BY usage_date, service_type
),
combined AS (
    SELECT * FROM analyst UNION ALL
    SELECT * FROM ai_functions UNION ALL
    SELECT * FROM search UNION ALL
    SELECT * FROM search_serving UNION ALL
    SELECT * FROM agent UNION ALL
    SELECT * FROM intelligence UNION ALL
    SELECT * FROM code_cli UNION ALL
    SELECT * FROM fine_tuning UNION ALL
    SELECT * FROM doc_processing UNION ALL
    SELECT * FROM rest_api UNION ALL
    SELECT * FROM legacy_functions UNION ALL
    SELECT * FROM provisioned
)
SELECT
    usage_date,
    service_type,
    daily_unique_users,
    total_operations,
    ROUND(total_credits, 6)                                                         AS total_credits,
    CASE WHEN daily_unique_users > 0 THEN ROUND(total_credits / daily_unique_users, 6) ELSE 0 END AS credits_per_user,
    CASE WHEN total_operations > 0   THEN ROUND(total_credits / total_operations, 6)   ELSE 0 END AS credits_per_operation
FROM combined
ORDER BY usage_date DESC, total_credits DESC;
