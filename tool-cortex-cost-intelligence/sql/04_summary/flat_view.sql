USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_COST_INTELLIGENCE_FLAT
COMMENT = 'DEMO: Cortex Cost Intelligence - Single denormalized view for BI tools (Tableau, PowerBI, Sigma, Hex) | See deploy_all.sql for expiration'
AS
WITH config AS (
    SELECT setting_value::NUMBER(10,2) AS credit_cost_usd
    FROM CORTEX_USAGE_CONFIG
    WHERE setting_name = 'CREDIT_COST_USD'
),
analyst AS (
    SELECT
        usage_date,
        'Cortex Analyst'    AS service_type,
        user_name,
        NULL                AS model_name,
        NULL                AS function_name,
        NULL                AS role_name,
        credits,
        operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        NULL::NUMBER        AS tokens_total
    FROM V_CORTEX_ANALYST_DETAIL
),
ai_functions AS (
    SELECT
        usage_date,
        'Cortex AI Functions' AS service_type,
        u.name              AS user_name,
        f.model_name,
        f.function_name,
        ARRAY_TO_STRING(f.role_names, ',') AS role_name,
        f.credits,
        1                   AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        NULL::NUMBER        AS tokens_total
    FROM V_CORTEX_AI_FUNCTIONS_DETAIL f
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON f.user_id = u.user_id
),
agent AS (
    SELECT
        usage_date,
        'Cortex Agent'      AS service_type,
        user_name,
        NULL                AS model_name,
        agent_name          AS function_name,
        NULL                AS role_name,
        credits,
        1                   AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        tokens              AS tokens_total
    FROM V_CORTEX_AGENT_DETAIL
),
intelligence AS (
    SELECT
        usage_date,
        'Snowflake Intelligence' AS service_type,
        user_name,
        NULL                AS model_name,
        snowflake_intelligence_name AS function_name,
        NULL                AS role_name,
        credits,
        1                   AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        tokens              AS tokens_total
    FROM V_SNOWFLAKE_INTELLIGENCE_DETAIL
),
code_cli AS (
    SELECT
        usage_date,
        'Cortex Code CLI'   AS service_type,
        u.name              AS user_name,
        NULL                AS model_name,
        NULL                AS function_name,
        NULL                AS role_name,
        c.credits,
        1                   AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        c.tokens            AS tokens_total
    FROM V_CORTEX_CODE_CLI_DETAIL c
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON c.user_id = u.user_id
),
search AS (
    SELECT
        usage_date,
        'Cortex Search'     AS service_type,
        NULL                AS user_name,
        model_name,
        service_name        AS function_name,
        NULL                AS role_name,
        credits,
        1                   AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        tokens              AS tokens_total
    FROM V_CORTEX_SEARCH_DETAIL
),
search_serving AS (
    SELECT
        usage_date,
        'Cortex Search Serving' AS service_type,
        NULL                AS user_name,
        NULL                AS model_name,
        service_name        AS function_name,
        NULL                AS role_name,
        credits,
        1                   AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        NULL::NUMBER        AS tokens_total
    FROM V_CORTEX_SEARCH_SERVING_DETAIL
),
fine_tuning AS (
    SELECT
        usage_date,
        'Fine-Tuning'       AS service_type,
        NULL                AS user_name,
        model_name,
        NULL                AS function_name,
        NULL                AS role_name,
        credits,
        1                   AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        tokens              AS tokens_total
    FROM V_CORTEX_FINE_TUNING_DETAIL
),
doc_processing AS (
    SELECT
        usage_date,
        'Document Processing' AS service_type,
        NULL                AS user_name,
        model_name,
        function_name,
        NULL                AS role_name,
        credits,
        document_count      AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        NULL::NUMBER        AS tokens_total
    FROM V_CORTEX_DOCUMENT_PROCESSING_DETAIL
),
rest_api AS (
    SELECT
        usage_date,
        'Cortex REST API'   AS service_type,
        u.name              AS user_name,
        r.model_name,
        NULL                AS function_name,
        NULL                AS role_name,
        0::NUMBER(38,6)     AS credits,
        1                   AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        r.tokens            AS tokens_total
    FROM V_CORTEX_REST_API_DETAIL r
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON r.user_id = u.user_id
),
legacy_functions AS (
    SELECT
        usage_date,
        'Cortex Functions (Legacy)' AS service_type,
        NULL                AS user_name,
        model_name,
        function_name,
        NULL                AS role_name,
        credits,
        1                   AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        tokens              AS tokens_total
    FROM V_CORTEX_FUNCTIONS_DETAIL
),
provisioned AS (
    SELECT
        usage_date,
        'Provisioned Throughput' AS service_type,
        NULL                AS user_name,
        model_name,
        ai_service          AS function_name,
        NULL                AS role_name,
        credits,
        1                   AS operations,
        NULL::NUMBER        AS tokens_input,
        NULL::NUMBER        AS tokens_output,
        NULL::NUMBER        AS tokens_total
    FROM V_CORTEX_PROVISIONED_THROUGHPUT_DETAIL
),
combined AS (
    SELECT * FROM analyst UNION ALL
    SELECT * FROM ai_functions UNION ALL
    SELECT * FROM agent UNION ALL
    SELECT * FROM intelligence UNION ALL
    SELECT * FROM code_cli UNION ALL
    SELECT * FROM search UNION ALL
    SELECT * FROM search_serving UNION ALL
    SELECT * FROM fine_tuning UNION ALL
    SELECT * FROM doc_processing UNION ALL
    SELECT * FROM rest_api UNION ALL
    SELECT * FROM legacy_functions UNION ALL
    SELECT * FROM provisioned
),
enriched AS (
    SELECT
        c.usage_date,
        DATE_TRUNC('week', c.usage_date)::DATE               AS usage_week,
        DATE_TRUNC('month', c.usage_date)::DATE              AS usage_month,
        DAYNAME(c.usage_date)                                 AS day_of_week,
        c.service_type,
        COALESCE(c.user_name, 'SYSTEM')                      AS user_name,
        c.model_name,
        c.function_name,
        c.role_name,
        c.credits,
        c.operations,
        c.tokens_input,
        c.tokens_output,
        c.tokens_total,
        ROUND(c.credits * cfg.credit_cost_usd, 4)            AS cost_usd
    FROM combined c
    CROSS JOIN config cfg
)
SELECT
    usage_date,
    usage_week,
    usage_month,
    day_of_week,
    service_type,
    user_name,
    model_name,
    function_name,
    role_name,
    ROUND(credits, 6)                                          AS credits,
    operations,
    tokens_input,
    tokens_output,
    tokens_total,
    cost_usd,
    SUM(credits) OVER (
        PARTITION BY service_type, DATE_TRUNC('month', usage_date)
        ORDER BY usage_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                           AS mtd_credits,
    SUM(cost_usd) OVER (
        PARTITION BY service_type, DATE_TRUNC('month', usage_date)
        ORDER BY usage_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                           AS mtd_cost_usd
FROM enriched;
