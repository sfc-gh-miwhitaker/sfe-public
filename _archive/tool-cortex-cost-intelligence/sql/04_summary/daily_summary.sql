USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_DAILY_SUMMARY
COMMENT = 'DEMO: Cortex Cost Intelligence - Daily summary across all Cortex services | See deploy_all.sql for expiration'
AS
WITH config AS (
    SELECT setting_value::NUMBER(10,2) AS credit_cost_usd
    FROM CORTEX_USAGE_CONFIG
    WHERE setting_name = 'CREDIT_COST_USD'
),
analyst AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_name) AS daily_unique_users, SUM(operations) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
    FROM V_CORTEX_ANALYST_DETAIL GROUP BY usage_date, service_type
),
ai_functions AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_id) AS daily_unique_users, COUNT(query_id) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
    FROM V_CORTEX_AI_FUNCTIONS_DETAIL GROUP BY usage_date, service_type
),
search AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
    FROM V_CORTEX_SEARCH_DETAIL GROUP BY usage_date, service_type
),
search_serving AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
    FROM V_CORTEX_SEARCH_SERVING_DETAIL GROUP BY usage_date, service_type
),
agent AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_name) AS daily_unique_users, COUNT(request_id) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
    FROM V_CORTEX_AGENT_DETAIL GROUP BY usage_date, service_type
),
intelligence AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_name) AS daily_unique_users, COUNT(request_id) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
    FROM V_SNOWFLAKE_INTELLIGENCE_DETAIL GROUP BY usage_date, service_type
),
code_cli AS (
    SELECT usage_date, service_type, COUNT(DISTINCT user_id) AS daily_unique_users, COUNT(request_id) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
    FROM V_CORTEX_CODE_CLI_DETAIL GROUP BY usage_date, service_type
),
fine_tuning AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
    FROM V_CORTEX_FINE_TUNING_DETAIL GROUP BY usage_date, service_type
),
doc_processing AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(query_id) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
    FROM V_CORTEX_DOCUMENT_PROCESSING_DETAIL GROUP BY usage_date, service_type
),
rest_api AS (
    SELECT
        r.usage_date,
        r.service_type,
        COUNT(DISTINCT r.user_id)  AS daily_unique_users,
        COUNT(r.request_id)        AS total_operations,
        NULL::NUMBER(38,6)         AS total_credits,
        ROUND(SUM(
            (COALESCE(r.tokens_input,  0) / 1e6 * COALESCE(p.input_usd_per_m,  0))
          + (COALESCE(r.tokens_output, 0) / 1e6 * COALESCE(p.output_usd_per_m, 0))
        ), 4)                      AS total_cost_usd_direct
    FROM V_CORTEX_REST_API_DETAIL r
    LEFT JOIN REST_API_PRICING p ON r.model_name = p.model_name
    GROUP BY r.usage_date, r.service_type
),
legacy_functions AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
    FROM V_CORTEX_FUNCTIONS_DETAIL GROUP BY usage_date, service_type
),
provisioned AS (
    SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct
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
    c.usage_date,
    c.service_type,
    c.daily_unique_users,
    c.total_operations,
    ROUND(c.total_credits, 6)                                                                                  AS total_credits,
    CASE WHEN c.daily_unique_users > 0 THEN ROUND(c.total_credits / c.daily_unique_users, 6) ELSE 0 END       AS credits_per_user,
    CASE WHEN c.total_operations > 0   THEN ROUND(c.total_credits / c.total_operations, 6)   ELSE 0 END       AS credits_per_operation,
    ROUND(COALESCE(c.total_cost_usd_direct, c.total_credits * cfg.credit_cost_usd), 4)                        AS total_cost_usd
FROM combined c
CROSS JOIN config cfg
ORDER BY c.usage_date DESC, total_cost_usd DESC;
