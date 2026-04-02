USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_MODEL_EFFICIENCY
COMMENT = 'DEMO: Cortex Cost Intelligence - Cross-service model cost efficiency comparison | See deploy_all.sql for expiration'
AS
WITH ai_functions_models AS (
    SELECT
        model_name,
        function_name,
        'Cortex AI Functions'    AS source_service,
        COUNT(query_id)          AS total_requests,
        SUM(credits)             AS total_credits,
        AVG(credits)             AS avg_credits_per_request
    FROM V_CORTEX_AI_FUNCTIONS_DETAIL
    WHERE model_name IS NOT NULL
      AND credits > 0
    GROUP BY model_name, function_name
),
legacy_functions_models AS (
    SELECT
        model_name,
        function_name,
        'Cortex Functions (Legacy)' AS source_service,
        COUNT(*)                 AS total_requests,
        SUM(credits)             AS total_credits,
        AVG(credits)             AS avg_credits_per_request
    FROM V_CORTEX_FUNCTIONS_DETAIL
    WHERE model_name IS NOT NULL
      AND credits > 0
    GROUP BY model_name, function_name
),
fine_tuning_models AS (
    SELECT
        model_name,
        NULL                     AS function_name,
        'Fine-Tuning'            AS source_service,
        COUNT(*)                 AS total_requests,
        SUM(credits)             AS total_credits,
        AVG(credits)             AS avg_credits_per_request
    FROM V_CORTEX_FINE_TUNING_DETAIL
    WHERE model_name IS NOT NULL
      AND credits > 0
    GROUP BY model_name
),
all_models AS (
    SELECT model_name, function_name, source_service, total_requests, total_credits, avg_credits_per_request FROM ai_functions_models
    UNION ALL
    SELECT model_name, function_name, source_service, total_requests, total_credits, avg_credits_per_request FROM legacy_functions_models
    UNION ALL
    SELECT model_name, function_name, source_service, total_requests, total_credits, avg_credits_per_request FROM fine_tuning_models
)
SELECT
    model_name,
    function_name,
    source_service,
    total_requests,
    ROUND(total_credits, 6)             AS total_credits,
    ROUND(avg_credits_per_request, 8)   AS avg_credits_per_request,
    RANK() OVER (
        PARTITION BY function_name
        ORDER BY avg_credits_per_request ASC
    )                                    AS cost_rank_for_function
FROM all_models
ORDER BY function_name NULLS LAST, avg_credits_per_request ASC;
