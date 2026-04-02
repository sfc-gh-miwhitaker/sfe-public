/*
 * Cortex Cost Intelligence v4.0 — deploy_all.sql
 *
 * Single-script deployment for the full Cortex Cost Intelligence platform.
 * Supports both Git integration and manual execution.
 *
 * What gets deployed:
 *   Tier 1 (always): Monitoring views, flat view, snapshot table, config
 *   Tier 2 (always): Semantic view + Cortex Agent (Snowflake Intelligence)
 *   Tier 3 (opt-in): Governance module (budgets, alerts, runaway detection)
 *   Tier 4 (opt-in): Streamlit dashboard
 *
 * Usage:
 *   -- Manual: Run this entire script in a Snowsight worksheet
 *   -- Git:    EXECUTE IMMEDIATE FROM @git_repo/branches/main/tool-cortex-cost-intelligence/deploy_all.sql
 *
 * Cleanup:
 *   Run sql/99_cleanup/cleanup_all.sql to remove all objects.
 */

-- ============================================================
-- Tier 1: Core Foundation
-- ============================================================
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'DEMO: Repository for example/demo projects | 90-day expiration';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE
    COMMENT = 'DEMO: Cortex Cost Intelligence - AI cost governance platform | 90-day expiration';

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

-- Config table
CREATE TRANSIENT TABLE IF NOT EXISTS CORTEX_USAGE_CONFIG (
    setting_name    VARCHAR(100) PRIMARY KEY,
    setting_value   VARCHAR(1000) NOT NULL,
    description     VARCHAR(500),
    data_type       VARCHAR(50) DEFAULT 'STRING',
    updated_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_by      VARCHAR(100) DEFAULT CURRENT_USER()
);

MERGE INTO CORTEX_USAGE_CONFIG AS target
USING (
    SELECT column1 AS setting_name, column2 AS setting_value, column3 AS description, column4 AS data_type
    FROM VALUES
        ('LOOKBACK_DAYS',              '90',    'Default lookback period for monitoring views (days)', 'INTEGER'),
        ('SNAPSHOT_RETENTION_DAYS',    '365',   'How long to keep historical snapshots (days)',        'INTEGER'),
        ('CREDIT_COST_USD',            '3.00',  'Default Snowflake credit cost in USD',                'DECIMAL'),
        ('ANOMALY_THRESHOLD_HIGH',     '0.50',  'WoW growth threshold for HIGH alerts (50%)',          'DECIMAL'),
        ('ANOMALY_THRESHOLD_MEDIUM',   '0.25',  'WoW growth threshold for MEDIUM alerts (25%)',        'DECIMAL'),
        ('FORECAST_HORIZON_DAYS',      '365',   'Forecast horizon in days',                            'INTEGER'),
        ('MIN_DATA_POINTS_FORECAST',   '14',    'Minimum days of data for forecasting',                'INTEGER'),
        ('ENABLE_GOVERNANCE',          'FALSE', 'Enable governance module',                            'BOOLEAN'),
        ('ENABLE_STREAMLIT',           'TRUE',  'Deploy optional Streamlit dashboard',                 'BOOLEAN'),
        ('CONFIG_VERSION',             '4.0',   'Configuration schema version',                        'STRING'),
        ('DEPLOYMENT_DATE', CURRENT_TIMESTAMP()::VARCHAR, 'Date of deployment', 'TIMESTAMP')
) AS source
ON target.setting_name = source.setting_name
WHEN MATCHED THEN UPDATE SET
    target.description = source.description,
    target.data_type   = source.data_type
WHEN NOT MATCHED THEN INSERT (setting_name, setting_value, description, data_type)
VALUES (source.setting_name, source.setting_value, source.description, source.data_type);

-- REST API pricing (billed in USD per token, not credits — Consumption Table 6c)
CREATE TRANSIENT TABLE IF NOT EXISTS REST_API_PRICING (
    model_name          VARCHAR(100) PRIMARY KEY,
    input_usd_per_m     NUMBER(10,4) NOT NULL,
    output_usd_per_m    NUMBER(10,4) NOT NULL,
    effective_date       DATE DEFAULT CURRENT_DATE(),
    updated_at           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO REST_API_PRICING AS target
USING (
    SELECT column1 AS model_name, column2 AS input_usd_per_m, column3 AS output_usd_per_m
    FROM VALUES
        ('claude-3-5-sonnet',          3.00,   15.00),
        ('deepseek-r1',                1.35,    5.40),
        ('llama3.1-405b',              2.40,    2.40),
        ('llama3.1-70b',               0.72,    0.72),
        ('llama3.1-8b',                0.22,    0.22),
        ('llama3.2-1b',                0.10,    0.10),
        ('llama3.2-3b',                0.15,    0.15),
        ('llama3.3-70b',               0.72,    0.72),
        ('llama4-maverick',            0.24,    0.97),
        ('mistral-large',              4.00,   12.00),
        ('mistral-large2',             2.00,    6.00),
        ('mistral-7b',                 0.15,    0.20),
        ('openai-gpt-oss-120b',        0.15,    0.60),
        ('snowflake-llama-3.3-70b',    0.72,    0.72)
) AS source
ON target.model_name = source.model_name
WHEN NOT MATCHED THEN INSERT (model_name, input_usd_per_m, output_usd_per_m)
VALUES (source.model_name, source.input_usd_per_m, source.output_usd_per_m);

-- Snapshot table
CREATE TRANSIENT TABLE IF NOT EXISTS CORTEX_USAGE_SNAPSHOTS (
    snapshot_date               DATE        NOT NULL,
    service_type                VARCHAR(100),
    daily_unique_users          NUMBER,
    total_operations            NUMBER,
    total_credits               NUMBER(38,6),
    credits_per_user            NUMBER(38,6),
    credits_per_operation       NUMBER(38,6),
    snapshot_created_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================
-- Service Views (02_service_views)
-- ============================================================

CREATE OR REPLACE VIEW V_CORTEX_ANALYST_DETAIL AS
SELECT start_time, end_time, DATE_TRUNC('day', start_time)::DATE AS usage_date,
    username AS user_name, 'Cortex Analyst' AS service_type, credits,
    request_count AS operations,
    CASE WHEN request_count > 0 THEN ROUND(credits / request_count, 6) ELSE 0 END AS credits_per_operation
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_AI_FUNCTIONS_DETAIL AS
SELECT start_time, end_time, DATE_TRUNC('day', start_time)::DATE AS usage_date,
    function_name, model_name, query_id, warehouse_id, role_names, query_tag, user_id,
    'Cortex AI Functions' AS service_type, credits, is_completed, metrics
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_AGENT_DETAIL AS
SELECT start_time, end_time, DATE_TRUNC('day', start_time)::DATE AS usage_date,
    user_id, user_name, request_id, parent_request_id,
    agent_database_name, agent_schema_name, agent_id, agent_name,
    'Cortex Agent' AS service_type, token_credits AS credits, tokens, tokens_granular, credits_granular, metadata
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_SNOWFLAKE_INTELLIGENCE_DETAIL AS
SELECT start_time, end_time, DATE_TRUNC('day', start_time)::DATE AS usage_date,
    user_id, user_name, request_id, snowflake_intelligence_id, snowflake_intelligence_name,
    agent_database_name, agent_schema_name, agent_id, agent_name,
    'Snowflake Intelligence' AS service_type, token_credits AS credits, tokens, tokens_granular, credits_granular, metadata
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_CODE_CLI_DETAIL AS
SELECT usage_time, DATE_TRUNC('day', usage_time)::DATE AS usage_date,
    user_id, request_id, parent_request_id,
    'Cortex Code CLI' AS service_type, token_credits AS credits, tokens, tokens_granular, credits_granular
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_SEARCH_DETAIL AS
SELECT usage_date::DATE AS usage_date, database_name, schema_name, service_name, service_id,
    consumption_type, 'Cortex Search' AS service_type, model_name, credits, tokens, warehouse_id
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
WHERE usage_date >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_SEARCH_SERVING_DETAIL AS
SELECT start_time, end_time, DATE_TRUNC('day', start_time)::DATE AS usage_date,
    database_name, schema_name, service_name, service_id,
    'Cortex Search Serving' AS service_type, credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_SERVING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_FUNCTIONS_DETAIL AS
SELECT start_time, end_time, DATE_TRUNC('day', start_time)::DATE AS usage_date,
    function_name, model_name, warehouse_id,
    'Cortex Functions (Legacy)' AS service_type, token_credits AS credits, tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_FINE_TUNING_DETAIL AS
SELECT start_time, end_time, DATE_TRUNC('day', start_time)::DATE AS usage_date,
    model_name, 'Fine-Tuning' AS service_type, token_credits AS credits, tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FINE_TUNING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_DOCUMENT_PROCESSING_DETAIL AS
SELECT start_time, end_time, DATE_TRUNC('day', start_time)::DATE AS usage_date,
    query_id, function_name, model_name, operation_name,
    'Document Processing' AS service_type, credits_used AS credits, page_count, document_count, feature_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_REST_API_DETAIL AS
SELECT start_time, end_time, DATE_TRUNC('day', start_time)::DATE AS usage_date,
    request_id, model_name, user_id, inference_region,
    'Cortex REST API' AS service_type, tokens, tokens_granular,
    tokens_granular:"input"::NUMBER AS tokens_input,
    tokens_granular:"output"::NUMBER AS tokens_output
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_PROVISIONED_THROUGHPUT_DETAIL AS
SELECT interval_start_time AS start_time, interval_end_time AS end_time,
    DATE_TRUNC('day', interval_start_time)::DATE AS usage_date,
    provisioned_throughput_id, ai_service, cloud_service_provider, model_name,
    term_start_date, term_end_date, 'Provisioned Throughput' AS service_type,
    ptu_count, ptu_credits AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_PROVISIONED_THROUGHPUT_USAGE_HISTORY
WHERE interval_start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- ============================================================
-- Attribution Views (03_attribution)
-- ============================================================

CREATE OR REPLACE VIEW V_USER_SPEND_ATTRIBUTION AS
WITH analyst_users AS (
    SELECT usage_date, user_name, 'Cortex Analyst' AS service_type, NULL AS model_name, NULL AS function_name, credits, operations
    FROM V_CORTEX_ANALYST_DETAIL
),
ai_functions_users AS (
    SELECT f.usage_date, u.name AS user_name, 'Cortex AI Functions' AS service_type, f.model_name, f.function_name,
        SUM(f.credits) AS credits, COUNT(f.query_id) AS operations
    FROM V_CORTEX_AI_FUNCTIONS_DETAIL f
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON f.user_id = u.user_id
    GROUP BY f.usage_date, u.name, f.model_name, f.function_name
),
agent_users AS (
    SELECT usage_date, user_name, 'Cortex Agent' AS service_type, NULL AS model_name, agent_name AS function_name,
        SUM(credits) AS credits, COUNT(request_id) AS operations
    FROM V_CORTEX_AGENT_DETAIL GROUP BY usage_date, user_name, agent_name
),
intelligence_users AS (
    SELECT usage_date, user_name, 'Snowflake Intelligence' AS service_type, NULL AS model_name, snowflake_intelligence_name AS function_name,
        SUM(credits) AS credits, COUNT(request_id) AS operations
    FROM V_SNOWFLAKE_INTELLIGENCE_DETAIL GROUP BY usage_date, user_name, snowflake_intelligence_name
),
all_users AS (
    SELECT * FROM analyst_users UNION ALL SELECT * FROM ai_functions_users
    UNION ALL SELECT * FROM agent_users UNION ALL SELECT * FROM intelligence_users
)
SELECT usage_date, user_name, service_type, model_name, function_name,
    credits AS credits_used, operations,
    CASE WHEN operations > 0 THEN ROUND(credits / operations, 6) ELSE 0 END AS credits_per_operation
FROM all_users WHERE user_name IS NOT NULL;

CREATE OR REPLACE VIEW V_MODEL_EFFICIENCY AS
WITH ai_functions_models AS (
    SELECT model_name, function_name, 'Cortex AI Functions' AS source_service,
        COUNT(query_id) AS total_requests, SUM(credits) AS total_credits, AVG(credits) AS avg_credits_per_request
    FROM V_CORTEX_AI_FUNCTIONS_DETAIL WHERE model_name IS NOT NULL AND credits > 0
    GROUP BY model_name, function_name
),
legacy_functions_models AS (
    SELECT model_name, function_name, 'Cortex Functions (Legacy)' AS source_service,
        COUNT(*) AS total_requests, SUM(credits) AS total_credits, AVG(credits) AS avg_credits_per_request
    FROM V_CORTEX_FUNCTIONS_DETAIL WHERE model_name IS NOT NULL AND credits > 0
    GROUP BY model_name, function_name
),
fine_tuning_models AS (
    SELECT model_name, NULL AS function_name, 'Fine-Tuning' AS source_service,
        COUNT(*) AS total_requests, SUM(credits) AS total_credits, AVG(credits) AS avg_credits_per_request
    FROM V_CORTEX_FINE_TUNING_DETAIL WHERE model_name IS NOT NULL AND credits > 0
    GROUP BY model_name
),
all_models AS (
    SELECT * FROM ai_functions_models UNION ALL SELECT * FROM legacy_functions_models UNION ALL SELECT * FROM fine_tuning_models
)
SELECT model_name, function_name, source_service, total_requests,
    ROUND(total_credits, 6) AS total_credits, ROUND(avg_credits_per_request, 8) AS avg_credits_per_request,
    RANK() OVER (PARTITION BY function_name ORDER BY avg_credits_per_request ASC) AS cost_rank_for_function
FROM all_models ORDER BY function_name NULLS LAST, avg_credits_per_request ASC;

-- ============================================================
-- Summary Views (04_summary)
-- ============================================================

CREATE OR REPLACE VIEW V_CORTEX_DAILY_SUMMARY AS
WITH config AS (SELECT setting_value::NUMBER(10,2) AS credit_cost_usd FROM CORTEX_USAGE_CONFIG WHERE setting_name = 'CREDIT_COST_USD'),
analyst AS (SELECT usage_date, service_type, COUNT(DISTINCT user_name) AS daily_unique_users, SUM(operations) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_CORTEX_ANALYST_DETAIL GROUP BY usage_date, service_type),
ai_functions AS (SELECT usage_date, service_type, COUNT(DISTINCT user_id) AS daily_unique_users, COUNT(query_id) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_CORTEX_AI_FUNCTIONS_DETAIL GROUP BY usage_date, service_type),
search AS (SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_CORTEX_SEARCH_DETAIL GROUP BY usage_date, service_type),
search_serving AS (SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_CORTEX_SEARCH_SERVING_DETAIL GROUP BY usage_date, service_type),
agent AS (SELECT usage_date, service_type, COUNT(DISTINCT user_name) AS daily_unique_users, COUNT(request_id) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_CORTEX_AGENT_DETAIL GROUP BY usage_date, service_type),
intelligence AS (SELECT usage_date, service_type, COUNT(DISTINCT user_name) AS daily_unique_users, COUNT(request_id) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_SNOWFLAKE_INTELLIGENCE_DETAIL GROUP BY usage_date, service_type),
code_cli AS (SELECT usage_date, service_type, COUNT(DISTINCT user_id) AS daily_unique_users, COUNT(request_id) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_CORTEX_CODE_CLI_DETAIL GROUP BY usage_date, service_type),
fine_tuning AS (SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_CORTEX_FINE_TUNING_DETAIL GROUP BY usage_date, service_type),
doc_processing AS (SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(query_id) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_CORTEX_DOCUMENT_PROCESSING_DETAIL GROUP BY usage_date, service_type),
rest_api AS (
    SELECT r.usage_date, r.service_type, COUNT(DISTINCT r.user_id) AS daily_unique_users, COUNT(r.request_id) AS total_operations,
        NULL::NUMBER(38,6) AS total_credits,
        ROUND(SUM((COALESCE(r.tokens_input, 0) / 1e6 * COALESCE(p.input_usd_per_m, 0)) + (COALESCE(r.tokens_output, 0) / 1e6 * COALESCE(p.output_usd_per_m, 0))), 4) AS total_cost_usd_direct
    FROM V_CORTEX_REST_API_DETAIL r LEFT JOIN REST_API_PRICING p ON r.model_name = p.model_name
    GROUP BY r.usage_date, r.service_type
),
legacy_functions AS (SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_CORTEX_FUNCTIONS_DETAIL GROUP BY usage_date, service_type),
provisioned AS (SELECT usage_date, service_type, 0 AS daily_unique_users, COUNT(*) AS total_operations, SUM(credits) AS total_credits, NULL::NUMBER(38,6) AS total_cost_usd_direct FROM V_CORTEX_PROVISIONED_THROUGHPUT_DETAIL GROUP BY usage_date, service_type),
combined AS (
    SELECT * FROM analyst UNION ALL SELECT * FROM ai_functions UNION ALL SELECT * FROM search
    UNION ALL SELECT * FROM search_serving UNION ALL SELECT * FROM agent UNION ALL SELECT * FROM intelligence
    UNION ALL SELECT * FROM code_cli UNION ALL SELECT * FROM fine_tuning UNION ALL SELECT * FROM doc_processing
    UNION ALL SELECT * FROM rest_api UNION ALL SELECT * FROM legacy_functions UNION ALL SELECT * FROM provisioned
)
SELECT c.usage_date, c.service_type, c.daily_unique_users, c.total_operations,
    ROUND(c.total_credits, 6) AS total_credits,
    CASE WHEN c.daily_unique_users > 0 THEN ROUND(c.total_credits / c.daily_unique_users, 6) ELSE 0 END AS credits_per_user,
    CASE WHEN c.total_operations > 0 THEN ROUND(c.total_credits / c.total_operations, 6) ELSE 0 END AS credits_per_operation,
    ROUND(COALESCE(c.total_cost_usd_direct, c.total_credits * cfg.credit_cost_usd), 4) AS total_cost_usd
FROM combined c CROSS JOIN config cfg
ORDER BY c.usage_date DESC, total_cost_usd DESC;

CREATE OR REPLACE VIEW V_COST_ANOMALIES AS
WITH weekly_spend AS (
    SELECT DATE_TRUNC('week', usage_date)::DATE AS week_start, service_type, SUM(total_credits) AS weekly_credits
    FROM V_CORTEX_DAILY_SUMMARY GROUP BY DATE_TRUNC('week', usage_date), service_type
),
with_prev AS (
    SELECT week_start, service_type, weekly_credits,
        LAG(weekly_credits) OVER (PARTITION BY service_type ORDER BY week_start) AS prev_week_credits
    FROM weekly_spend
)
SELECT week_start, service_type, ROUND(weekly_credits, 4) AS weekly_credits, ROUND(prev_week_credits, 4) AS prev_week_credits,
    ROUND(weekly_credits - COALESCE(prev_week_credits, 0), 4) AS absolute_change,
    CASE WHEN prev_week_credits > 0 THEN ROUND((weekly_credits - prev_week_credits) / prev_week_credits, 4) ELSE NULL END AS wow_growth_pct,
    CASE
        WHEN prev_week_credits > 0 AND (weekly_credits - prev_week_credits) / prev_week_credits >= 0.50 THEN 'HIGH'
        WHEN prev_week_credits > 0 AND (weekly_credits - prev_week_credits) / prev_week_credits >= 0.25 THEN 'MEDIUM'
        WHEN prev_week_credits > 0 AND (weekly_credits - prev_week_credits) / prev_week_credits >= 0.10 THEN 'LOW'
        ELSE 'NORMAL'
    END AS alert_severity
FROM with_prev WHERE prev_week_credits IS NOT NULL ORDER BY week_start DESC, alert_severity;

CREATE OR REPLACE VIEW V_COST_ANOMALIES_CURRENT AS
SELECT * FROM V_COST_ANOMALIES WHERE alert_severity IN ('HIGH', 'MEDIUM') AND week_start >= DATEADD('week', -4, CURRENT_DATE())
ORDER BY alert_severity, wow_growth_pct DESC;

CREATE OR REPLACE VIEW V_CORTEX_COST_EXPORT AS
WITH detail_summary AS (SELECT usage_date, SUM(total_credits) AS detail_credits FROM V_CORTEX_DAILY_SUMMARY GROUP BY usage_date),
metering AS (SELECT usage_date, credits_used_compute, credits_used_cloud_services, credits_used, credits_billed FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY WHERE service_type = 'AI_SERVICES' AND usage_date >= DATEADD('day', -90, CURRENT_DATE()))
SELECT COALESCE(d.usage_date, m.usage_date) AS usage_date, d.detail_credits, m.credits_used AS metering_credits_used, m.credits_billed AS metering_credits_billed,
    m.credits_used_compute, m.credits_used_cloud_services,
    ROUND(d.detail_credits - COALESCE(m.credits_used, 0), 6) AS variance_detail_vs_metering
FROM detail_summary d FULL OUTER JOIN metering m ON d.usage_date = m.usage_date ORDER BY COALESCE(d.usage_date, m.usage_date) DESC;

CREATE OR REPLACE VIEW V_CORTEX_USAGE_HISTORY AS
WITH live_data AS (SELECT usage_date, service_type, daily_unique_users, total_operations, total_credits, credits_per_user, credits_per_operation, 'LIVE' AS data_source FROM V_CORTEX_DAILY_SUMMARY),
snapshot_data AS (SELECT snapshot_date AS usage_date, service_type, daily_unique_users, total_operations, total_credits, credits_per_user, credits_per_operation, 'SNAPSHOT' AS data_source FROM CORTEX_USAGE_SNAPSHOTS WHERE snapshot_date < DATEADD('day', -90, CURRENT_DATE()))
SELECT * FROM live_data UNION ALL SELECT * FROM snapshot_data ORDER BY usage_date DESC, total_credits DESC;

CREATE OR REPLACE VIEW V_CORTEX_COST_FORECAST AS
SELECT usage_date, SUM(total_credits) AS daily_credits, 'ACTUAL' AS data_type
FROM V_CORTEX_DAILY_SUMMARY WHERE usage_date < CURRENT_DATE() GROUP BY usage_date ORDER BY usage_date;

-- ============================================================
-- Flat View (the BI interface)
-- ============================================================

CREATE OR REPLACE VIEW V_COST_INTELLIGENCE_FLAT AS
WITH config AS (SELECT setting_value::NUMBER(10,2) AS credit_cost_usd FROM CORTEX_USAGE_CONFIG WHERE setting_name = 'CREDIT_COST_USD'),
analyst AS (SELECT usage_date, 'Cortex Analyst' AS service_type, user_name, NULL AS model_name, NULL AS function_name, NULL AS role_name, credits, operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, NULL::NUMBER AS tokens_total FROM V_CORTEX_ANALYST_DETAIL),
ai_functions AS (SELECT f.usage_date, 'Cortex AI Functions' AS service_type, u.name AS user_name, f.model_name, f.function_name, ARRAY_TO_STRING(f.role_names, ',') AS role_name, f.credits, 1 AS operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, NULL::NUMBER AS tokens_total FROM V_CORTEX_AI_FUNCTIONS_DETAIL f LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON f.user_id = u.user_id),
agent AS (SELECT usage_date, 'Cortex Agent' AS service_type, user_name, NULL AS model_name, agent_name AS function_name, NULL AS role_name, credits, 1 AS operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, tokens AS tokens_total FROM V_CORTEX_AGENT_DETAIL),
intelligence AS (SELECT usage_date, 'Snowflake Intelligence' AS service_type, user_name, NULL AS model_name, snowflake_intelligence_name AS function_name, NULL AS role_name, credits, 1 AS operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, tokens AS tokens_total FROM V_SNOWFLAKE_INTELLIGENCE_DETAIL),
code_cli AS (SELECT c.usage_date, 'Cortex Code CLI' AS service_type, u.name AS user_name, NULL AS model_name, NULL AS function_name, NULL AS role_name, c.credits, 1 AS operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, c.tokens AS tokens_total FROM V_CORTEX_CODE_CLI_DETAIL c LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON c.user_id = u.user_id),
search AS (SELECT usage_date, 'Cortex Search' AS service_type, NULL AS user_name, model_name, service_name AS function_name, NULL AS role_name, credits, 1 AS operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, tokens AS tokens_total FROM V_CORTEX_SEARCH_DETAIL),
search_serving AS (SELECT usage_date, 'Cortex Search Serving' AS service_type, NULL AS user_name, NULL AS model_name, service_name AS function_name, NULL AS role_name, credits, 1 AS operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, NULL::NUMBER AS tokens_total FROM V_CORTEX_SEARCH_SERVING_DETAIL),
fine_tuning AS (SELECT usage_date, 'Fine-Tuning' AS service_type, NULL AS user_name, model_name, NULL AS function_name, NULL AS role_name, credits, 1 AS operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, tokens AS tokens_total FROM V_CORTEX_FINE_TUNING_DETAIL),
doc_processing AS (SELECT usage_date, 'Document Processing' AS service_type, NULL AS user_name, model_name, function_name, NULL AS role_name, credits, document_count AS operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, NULL::NUMBER AS tokens_total FROM V_CORTEX_DOCUMENT_PROCESSING_DETAIL),
rest_api AS (SELECT r.usage_date, 'Cortex REST API' AS service_type, u.name AS user_name, r.model_name, NULL AS function_name, NULL AS role_name, NULL::NUMBER(38,6) AS credits, 1 AS operations, r.tokens_input, r.tokens_output, r.tokens AS tokens_total FROM V_CORTEX_REST_API_DETAIL r LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON r.user_id = u.user_id),
legacy_functions AS (SELECT usage_date, 'Cortex Functions (Legacy)' AS service_type, NULL AS user_name, model_name, function_name, NULL AS role_name, credits, 1 AS operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, tokens AS tokens_total FROM V_CORTEX_FUNCTIONS_DETAIL),
provisioned AS (SELECT usage_date, 'Provisioned Throughput' AS service_type, NULL AS user_name, model_name, ai_service AS function_name, NULL AS role_name, credits, 1 AS operations, NULL::NUMBER AS tokens_input, NULL::NUMBER AS tokens_output, NULL::NUMBER AS tokens_total FROM V_CORTEX_PROVISIONED_THROUGHPUT_DETAIL),
combined AS (
    SELECT * FROM analyst UNION ALL SELECT * FROM ai_functions UNION ALL SELECT * FROM agent UNION ALL SELECT * FROM intelligence
    UNION ALL SELECT * FROM code_cli UNION ALL SELECT * FROM search UNION ALL SELECT * FROM search_serving UNION ALL SELECT * FROM fine_tuning
    UNION ALL SELECT * FROM doc_processing UNION ALL SELECT * FROM rest_api UNION ALL SELECT * FROM legacy_functions UNION ALL SELECT * FROM provisioned
),
enriched AS (
    SELECT c.usage_date, DATE_TRUNC('week', c.usage_date)::DATE AS usage_week, DATE_TRUNC('month', c.usage_date)::DATE AS usage_month,
        DAYNAME(c.usage_date) AS day_of_week, c.service_type, COALESCE(c.user_name, 'SYSTEM') AS user_name,
        c.model_name, c.function_name, c.role_name, c.credits, c.operations, c.tokens_input, c.tokens_output, c.tokens_total,
        CASE WHEN c.service_type = 'Cortex REST API' THEN 'USD' ELSE 'CREDITS' END AS billing_type,
        CASE
            WHEN c.service_type = 'Cortex REST API'
            THEN ROUND((COALESCE(c.tokens_input, 0) / 1e6 * COALESCE(p.input_usd_per_m, 0)) + (COALESCE(c.tokens_output, 0) / 1e6 * COALESCE(p.output_usd_per_m, 0)), 4)
            ELSE ROUND(c.credits * cfg.credit_cost_usd, 4)
        END AS cost_usd
    FROM combined c CROSS JOIN config cfg
    LEFT JOIN REST_API_PRICING p ON c.service_type = 'Cortex REST API' AND c.model_name = p.model_name
)
SELECT usage_date, usage_week, usage_month, day_of_week, service_type, user_name, model_name, function_name, role_name,
    ROUND(credits, 6) AS credits, operations, tokens_input, tokens_output, tokens_total, billing_type, cost_usd,
    SUM(credits) OVER (PARTITION BY service_type, DATE_TRUNC('month', usage_date) ORDER BY usage_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS mtd_credits,
    SUM(cost_usd) OVER (PARTITION BY service_type, DATE_TRUNC('month', usage_date) ORDER BY usage_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS mtd_cost_usd
FROM enriched;

-- Snapshot task
CREATE OR REPLACE TASK TASK_DAILY_CORTEX_SNAPSHOT
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    SCHEDULE = 'USING CRON 0 3 * * * America/Los_Angeles'
AS
    INSERT INTO CORTEX_USAGE_SNAPSHOTS (snapshot_date, service_type, daily_unique_users, total_operations, total_credits, credits_per_user, credits_per_operation)
    SELECT usage_date, service_type, daily_unique_users, total_operations, total_credits, credits_per_user, credits_per_operation
    FROM V_CORTEX_DAILY_SUMMARY
    WHERE usage_date = CURRENT_DATE() - 1
      AND NOT EXISTS (SELECT 1 FROM CORTEX_USAGE_SNAPSHOTS s WHERE s.snapshot_date = V_CORTEX_DAILY_SUMMARY.usage_date AND s.service_type = V_CORTEX_DAILY_SUMMARY.service_type);

ALTER TASK TASK_DAILY_CORTEX_SNAPSHOT RESUME;

-- ============================================================
-- Tier 2: Semantic View + Agent
-- ============================================================

BEGIN
    CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
        'SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.SV_CORTEX_COST_INTELLIGENCE',
        $$
name: cortex_cost_intelligence
description: "Cortex Cost Intelligence - natural-language cost analysis across all Snowflake Cortex AI services."
tables:
  - name: cortex_costs
    description: "Unified Cortex AI cost data."
    base_table:
      database: SNOWFLAKE_EXAMPLE
      schema: CORTEX_COST_INTELLIGENCE
      table: V_COST_INTELLIGENCE_FLAT
    dimensions:
      - name: service_type
        synonyms: ["service", "cortex service", "AI service"]
        description: "The Cortex AI service."
        expr: service_type
        data_type: VARCHAR
        is_enum: true
      - name: user_name
        synonyms: ["user", "username", "who"]
        description: "Snowflake user who incurred cost."
        expr: user_name
        data_type: VARCHAR
      - name: model_name
        synonyms: ["model", "LLM"]
        description: "AI model used."
        expr: model_name
        data_type: VARCHAR
      - name: function_name
        synonyms: ["function", "operation"]
        description: "Function, agent, or service name."
        expr: function_name
        data_type: VARCHAR
      - name: role_name
        synonyms: ["role"]
        description: "Snowflake role used."
        expr: role_name
        data_type: VARCHAR
      - name: billing_type
        synonyms: ["billing model", "pricing model", "charge type"]
        description: "How this service is billed. CREDITS for most services; USD for Cortex REST API (token-based pricing from Consumption Table 6c)."
        expr: billing_type
        data_type: VARCHAR
        is_enum: true
      - name: day_of_week
        synonyms: ["weekday"]
        description: "Day of week."
        expr: day_of_week
        data_type: VARCHAR
        is_enum: true
    time_dimensions:
      - name: usage_date
        synonyms: ["date", "day", "when"]
        description: "Calendar date of usage."
        expr: usage_date
        data_type: DATE
      - name: usage_week
        synonyms: ["week"]
        description: "Week start date."
        expr: usage_week
        data_type: DATE
      - name: usage_month
        synonyms: ["month"]
        description: "Month start date."
        expr: usage_month
        data_type: DATE
    facts:
      - name: credits
        synonyms: ["credit usage"]
        description: "Credits consumed. NULL for Cortex REST API (billed in USD per token, not credits)."
        expr: credits
        data_type: NUMBER
      - name: operations
        synonyms: ["requests", "calls"]
        description: "Operation count."
        expr: operations
        data_type: NUMBER
      - name: tokens_total
        synonyms: ["tokens"]
        description: "Total tokens."
        expr: tokens_total
        data_type: NUMBER
      - name: cost_usd
        synonyms: ["cost", "dollars", "spend"]
        description: "Estimated USD cost. Most services: credits × credit_cost_usd. REST API: token counts × per-model USD rates (Consumption Table 6c)."
        expr: cost_usd
        data_type: NUMBER
      - name: mtd_credits
        description: "Month-to-date credits."
        expr: mtd_credits
        data_type: NUMBER
      - name: mtd_cost_usd
        synonyms: ["MTD spend"]
        description: "Month-to-date USD cost."
        expr: mtd_cost_usd
        data_type: NUMBER
    metrics:
      - name: total_credits
        synonyms: ["total consumption"]
        description: "Sum of credits."
        expr: SUM(credits)
      - name: total_cost_usd
        synonyms: ["total cost", "total spend"]
        description: "Sum of USD costs."
        expr: SUM(cost_usd)
      - name: total_operations
        synonyms: ["total requests"]
        description: "Total operations."
        expr: SUM(operations)
      - name: unique_users
        synonyms: ["user count"]
        description: "Distinct users."
        expr: COUNT(DISTINCT user_name)
      - name: avg_credits_per_operation
        synonyms: ["unit cost"]
        description: "Avg credits per operation."
        expr: "CASE WHEN SUM(operations) > 0 THEN SUM(credits) / SUM(operations) ELSE 0 END"
    filters:
      - name: last_30_days
        description: "Last 30 days."
        expr: "usage_date >= DATEADD('day', -30, CURRENT_DATE())"
      - name: current_month
        description: "Current month."
        expr: "usage_month = DATE_TRUNC('month', CURRENT_DATE())"
      - name: non_system_users
        description: "Exclude SYSTEM."
        expr: "user_name != 'SYSTEM'"
verified_queries:
  - name: total_spend_last_month
    question: "What was our total Cortex spend last month?"
    use_as_onboarding_question: true
    sql: "SELECT SUM(cost_usd) AS total_cost_usd, SUM(credits) AS total_credits FROM cortex_cost_intelligence WHERE usage_month = DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()))"
  - name: top_spenders
    question: "Who are the top 10 spenders this month?"
    use_as_onboarding_question: true
    sql: "SELECT user_name, SUM(cost_usd) AS total_cost_usd, SUM(credits) AS total_credits FROM cortex_cost_intelligence WHERE usage_month = DATE_TRUNC('month', CURRENT_DATE()) AND user_name != 'SYSTEM' GROUP BY user_name ORDER BY total_cost_usd DESC LIMIT 10"
  - name: cost_by_service
    question: "How much does each Cortex service cost?"
    use_as_onboarding_question: true
    sql: "SELECT service_type, SUM(cost_usd) AS total_cost_usd, SUM(credits) AS total_credits FROM cortex_cost_intelligence WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE()) GROUP BY service_type ORDER BY total_cost_usd DESC"
  - name: cheapest_model
    question: "What is the cheapest model for COMPLETE?"
    use_as_onboarding_question: true
    sql: "SELECT model_name, SUM(credits) AS total_credits, SUM(operations) AS total_ops, CASE WHEN SUM(operations)>0 THEN SUM(credits)/SUM(operations) ELSE 0 END AS credits_per_op FROM cortex_cost_intelligence WHERE function_name='COMPLETE' AND model_name IS NOT NULL AND usage_date>=DATEADD('day',-30,CURRENT_DATE()) GROUP BY model_name ORDER BY credits_per_op ASC"
        $$,
        TRUE
    );
    GRANT SELECT ON SEMANTIC VIEW SV_CORTEX_COST_INTELLIGENCE TO ROLE PUBLIC;
EXCEPTION
    WHEN OTHER THEN
        SELECT 'Semantic view creation failed (may require specific privileges): ' || SQLERRM AS status;
END;

BEGIN
    CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
    GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE TO ROLE PUBLIC;
    CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS;
    GRANT USAGE ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE PUBLIC;

    CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.CORTEX_COST_INTELLIGENCE
        COMMENT = 'Cortex Cost Intelligence - Natural language cost analysis'
        PROFILE = '{"display_name": "Cortex Cost Intelligence"}'
        FROM SPECIFICATION $$
        {
            "models": {"orchestration": "claude-4-sonnet"},
            "instructions": {
                "orchestration": "You are a Cortex Cost Intelligence assistant. Use the cost_data tool to answer questions about Snowflake Cortex AI service costs, usage trends, user attribution, and model efficiency.",
                "response": "Be concise and data-driven. Format currency with 2 decimal places."
            },
            "tools": [{"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": "cost_data", "description": "Query Cortex AI cost and usage data across all services."}}],
            "tool_resources": {"cost_data": {"semantic_view": "SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.SV_CORTEX_COST_INTELLIGENCE", "execution_environment": {"type": "warehouse", "warehouse": "COMPUTE_WH"}, "query_timeout": 60}}
        }
        $$;
    GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.CORTEX_COST_INTELLIGENCE TO ROLE PUBLIC;
EXCEPTION
    WHEN OTHER THEN
        SELECT 'Agent creation failed (may require specific privileges): ' || SQLERRM AS status;
END;

-- ============================================================
-- Deployment Complete
-- ============================================================

SELECT 'Cortex Cost Intelligence v4.0 deployed successfully' AS status,
       CURRENT_TIMESTAMP() AS deployed_at,
       CURRENT_USER() AS deployed_by;
