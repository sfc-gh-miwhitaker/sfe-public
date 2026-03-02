/*******************************************************************************
 * DEMO PROJECT: Cortex Cost Calculator - Monitoring Views Deployment
 *
 * AUTHOR: SE Community
 * CREATED: 2026-01-05
 * EXPIRATION: See deploy_all.sql line 6 (SSOT)
 *
 * NOT FOR PRODUCTION USE - REFERENCE IMPLEMENTATION ONLY
 *
 * PURPOSE:
 *   Creates comprehensive monitoring infrastructure for all Cortex services:
 *   - 22 views (monitoring + attribution + forecast outputs)
 *   - 1 snapshot table for historical tracking
 *   - 1 serverless task for daily snapshots (3:00 AM Pacific)
 *
 * TARGET LOCATION:
 *   Database: SNOWFLAKE_EXAMPLE
 *   Schema: CORTEX_USAGE
 *
 * OBJECTS CREATED:
 *   Views (22):
 *   - V_CORTEX_ANALYST_DETAIL
 *   - V_CORTEX_SEARCH_DETAIL
 *   - V_CORTEX_SEARCH_SERVING_DETAIL
 *   - V_CORTEX_FUNCTIONS_DETAIL
 *   - V_CORTEX_FUNCTIONS_QUERY_DETAIL
 *   - V_DOCUMENT_AI_DETAIL (legacy)
 *   - V_CORTEX_DOCUMENT_PROCESSING_DETAIL
 *   - V_CORTEX_FINE_TUNING_DETAIL
 *   - V_CORTEX_REST_API_DETAIL
 *   - V_AISQL_FUNCTION_SUMMARY
 *   - V_AISQL_MODEL_COMPARISON
 *   - V_AISQL_DAILY_TRENDS
 *   - V_QUERY_COST_ANALYSIS
 *   - V_CORTEX_DAILY_SUMMARY
 *   - V_CORTEX_COST_EXPORT
 *   - V_METERING_AI_SERVICES
 *   - V_CORTEX_USAGE_HISTORY
 *   - V_USER_SPEND_ATTRIBUTION
 *   - V_USER_SPEND_SUMMARY
 *   - V_USER_FEATURE_USAGE
 *   - V_FORECAST_INPUT
 *   - V_USAGE_FORECAST_12M
 *
 *   Tables (1):
 *   - CORTEX_USAGE_SNAPSHOTS
 *
 *   Tasks (1):
 *   - TASK_DAILY_CORTEX_SNAPSHOT (serverless, runs 3:00 AM Pacific)
 *
 *   Models (1, optional):
 *   - CORTEX_USAGE_FORECAST_MODEL (SNOWFLAKE.ML.FORECAST; created when privileges are available)
 *
 * PREREQUISITES:
 *   - IMPORTED PRIVILEGES on SNOWFLAKE database OR ACCOUNTADMIN role
 *   - Active warehouse (any size)
 *
 * DEPLOYMENT METHOD:
 *   - Copy/paste into Snowsight OR
 *   - Execute via EXECUTE IMMEDIATE FROM Git stage
 *
 * DEPLOYMENT TIME: ~1 minute
 *
 * CLEANUP:
 *   See sql/99_cleanup/cleanup_all.sql
 *
 * VERSION: 3.3 (Updated Feb 2026 - REST API tracking, input/output tokens, Feb 2026 pricing)
 * LAST UPDATED: 2026-02-18
 ******************************************************************************/

-- ===========================================================================
-- EXPIRATION CHECK (MANDATORY)
-- ===========================================================================
-- This demo expires 30 days after creation. If expired, deployment is halted.
DECLARE
    demo_expired EXCEPTION (-20001, 'DEMO EXPIRED: Do not deploy. Fork the repository and update expiration + syntax.');
    expiration_date DATE := $demo_expiration_date::DATE;
BEGIN
    IF (CURRENT_DATE() > expiration_date) THEN
        RAISE demo_expired;
    END IF;
END;

-- ===========================================================================
-- SETUP: CREATE DATABASE & SCHEMA
-- ===========================================================================

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION | See deploy_all.sql for expiration';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.CORTEX_USAGE
    COMMENT = 'DEMO: Cortex service usage monitoring and cost tracking (v3.3) | See deploy_all.sql for expiration';

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- ===========================================================================
-- MONITORING VIEWS: CORTEX SERVICE DETAIL VIEWS
-- ===========================================================================
-- These views query SNOWFLAKE.ACCOUNT_USAGE for raw Cortex service data
-- Default retention: 90 days (adjust WHERE clause if needed)

-- View 1: Cortex Analyst Usage
-- Source: CORTEX_ANALYST_USAGE_HISTORY
-- Granularity: Per-request with username tracking
CREATE OR REPLACE VIEW V_CORTEX_ANALYST_DETAIL
    COMMENT = 'DEMO: cortex-trail - Cortex Analyst per-request usage with user tracking | See deploy_all.sql for expiration'
AS
SELECT
    'Cortex Analyst' AS service_type,
    DATE_TRUNC('day', start_time) AS usage_date,
    start_time,
    end_time,
    username,
    credits,
    request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 2: Cortex Search Usage (Daily Aggregates)
-- Source: CORTEX_SEARCH_DAILY_USAGE_HISTORY
-- Granularity: Daily per service (no user tracking available)
CREATE OR REPLACE VIEW V_CORTEX_SEARCH_DETAIL
    COMMENT = 'DEMO: cortex-trail - Cortex Search daily usage by service and model | See deploy_all.sql for expiration'
AS
SELECT
    'Cortex Search' AS service_type,
    usage_date::DATE AS usage_date,
    database_name,
    schema_name,
    service_name,
    service_id,
    consumption_type,
    credits,
    model_name,
    TRY_TO_NUMBER(tokens) AS tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
WHERE usage_date >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 3: Cortex Search Serving Usage
-- Source: CORTEX_SEARCH_SERVING_USAGE_HISTORY
-- Granularity: Per-query serving metrics
CREATE OR REPLACE VIEW V_CORTEX_SEARCH_SERVING_DETAIL
    COMMENT = 'DEMO: cortex-trail - Cortex Search serving query-level usage | See deploy_all.sql for expiration'
AS
SELECT
    'Cortex Search Serving' AS service_type,
    DATE_TRUNC('day', start_time) AS usage_date,
    start_time,
    end_time,
    database_name,
    schema_name,
    service_name,
    service_id,
    credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_SERVING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 4: Cortex Functions Usage (Hourly Aggregates)
-- Source: CORTEX_AISQL_USAGE_HISTORY
-- Granularity: Hourly per function/model (no user tracking)
CREATE OR REPLACE VIEW V_CORTEX_FUNCTIONS_DETAIL
    COMMENT = 'DEMO: cortex-trail - Cortex AI SQL functions hourly usage (CORTEX_AISQL_USAGE_HISTORY) | See deploy_all.sql for expiration'
AS
SELECT
    'Cortex Functions' AS service_type,
    DATE_TRUNC('day', usage_time) AS usage_date,
    usage_time AS start_time,
    DATEADD('hour', 1, usage_time) AS end_time,
    function_name,
    model_name,
    TRY_TO_NUMBER(warehouse_id) AS warehouse_id,
    token_credits,
    tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 5: Cortex Functions Query-Level Detail
-- Source: CORTEX_AISQL_USAGE_HISTORY
-- Granularity: Per-query with cost efficiency metrics
CREATE OR REPLACE VIEW V_CORTEX_FUNCTIONS_QUERY_DETAIL
    COMMENT = 'DEMO: cortex-trail - Per-query Cortex AI function usage with cost-per-million-tokens (CORTEX_AISQL_USAGE_HISTORY) | See deploy_all.sql for expiration'
AS
SELECT
    'Cortex Functions Query' AS service_type,
    query_id,
    TRY_TO_NUMBER(warehouse_id) AS warehouse_id,
    model_name,
    function_name,
    tokens,
    token_credits,
    tokens_granular,
    token_credits_granular,
    tokens_granular:"input"::NUMBER AS input_tokens,
    tokens_granular:"output"::NUMBER AS output_tokens,
    token_credits_granular:"input"::NUMBER(38,6) AS input_credits,
    token_credits_granular:"output"::NUMBER(38,6) AS output_credits,
    CASE
        WHEN tokens > 0 THEN (token_credits / tokens) * 1000000
        ELSE 0
    END AS cost_per_million_tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 6: Document AI Usage (Legacy)
-- Source: DOCUMENT_AI_USAGE_HISTORY
-- Note: Legacy service - use V_CORTEX_DOCUMENT_PROCESSING_DETAIL for new deployments
CREATE OR REPLACE VIEW V_DOCUMENT_AI_DETAIL
    COMMENT = 'DEMO: cortex-trail - Legacy Document AI usage (use V_CORTEX_DOCUMENT_PROCESSING_DETAIL for new) | See deploy_all.sql for expiration'
AS
SELECT
    'Document AI' AS service_type,
    DATE_TRUNC('day', start_time) AS usage_date,
    start_time,
    end_time,
    credits_used,
    query_id,
    operation_name,
    page_count,
    document_count,
    feature_count
FROM SNOWFLAKE.ACCOUNT_USAGE.DOCUMENT_AI_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 7: Cortex Document Processing (Unified)
-- Source: CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY (GA: Mar 3, 2025)
-- Supports: PARSE_DOCUMENT, AI_EXTRACT, Document AI
-- Granularity: Per-query with page/document metrics
CREATE OR REPLACE VIEW V_CORTEX_DOCUMENT_PROCESSING_DETAIL
    COMMENT = 'DEMO: cortex-trail - Unified document processing (PARSE_DOCUMENT, AI_EXTRACT) with efficiency metrics | See deploy_all.sql for expiration'
AS
SELECT
    'Cortex Document Processing' AS service_type,
    DATE_TRUNC('day', start_time) AS usage_date,
    query_id,
    credits_used,
    start_time,
    end_time,
    function_name,
    model_name,
    operation_name,
    page_count,
    document_count,
    feature_count,
    -- Calculate efficiency metrics
    CASE
        WHEN page_count > 0 THEN credits_used / page_count
        ELSE 0
    END AS credits_per_page,
    CASE
        WHEN document_count > 0 THEN credits_used / document_count
        ELSE 0
    END AS credits_per_document
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 8: Cortex Fine-Tuning Usage
-- Source: CORTEX_FINE_TUNING_USAGE_HISTORY (GA: Oct 10, 2024)
-- Granularity: Training job-level with token costs
CREATE OR REPLACE VIEW V_CORTEX_FINE_TUNING_DETAIL
    COMMENT = 'DEMO: cortex-trail - Fine-tuning training costs with cost-per-million-tokens | See deploy_all.sql for expiration'
AS
SELECT
    'Cortex Fine-tuning' AS service_type,
    DATE_TRUNC('day', start_time) AS usage_date,
    start_time,
    end_time,
    model_name,
    token_credits,
    tokens,
    -- Calculate cost per million tokens
    CASE
        WHEN tokens > 0 THEN (token_credits / tokens) * 1000000
        ELSE 0
    END AS cost_per_million_tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FINE_TUNING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 8.5: Cortex REST API Usage
-- Source: CORTEX_REST_API_USAGE_HISTORY
-- Granularity: Per-request with user attribution and cross-region tracking
-- Note: This view tracks TOKEN usage only; credits are not available per-request
--       in this view. Use V_METERING_AI_SERVICES to validate total AI_SERVICES credits.
CREATE OR REPLACE VIEW V_CORTEX_REST_API_DETAIL
    COMMENT = 'DEMO: cortex-trail - REST API per-request usage with user/model/region tracking (tokens only, no credits) | See deploy_all.sql for expiration'
AS
SELECT
    'Cortex REST API' AS service_type,
    DATE_TRUNC('day', start_time) AS usage_date,
    start_time,
    end_time,
    request_id,
    model_name,
    tokens,
    tokens_granular,
    tokens_granular:"input"::NUMBER AS input_tokens,
    tokens_granular:"output"::NUMBER AS output_tokens,
    user_id,
    inference_region
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- ===========================================================================
-- ANALYTICAL VIEWS: AGGREGATED ANALYSIS & SUMMARIES
-- ===========================================================================
-- These views provide higher-level analysis for cost forecasting

-- View 9: AISQL Function Summary (Aggregated by Function/Model)
-- Purpose: Function-level cost analysis for calculator inputs
CREATE OR REPLACE VIEW V_AISQL_FUNCTION_SUMMARY
    COMMENT = 'DEMO: cortex-trail - Function-level summary for cost-per-million-tokens analysis | See deploy_all.sql for expiration'
AS
SELECT
    function_name,
    model_name,
    COUNT(DISTINCT query_id) AS call_count,
    SUM(token_credits) AS total_credits,
    SUM(tokens) AS total_tokens,
    AVG(token_credits) AS avg_credits_per_call,
    AVG(tokens) AS avg_tokens_per_call,
    CASE
        WHEN SUM(tokens) > 0
        THEN SUM(token_credits) / SUM(tokens) * 1000000
        ELSE 0
    END AS cost_per_million_tokens,
    MIN(usage_time) AS first_usage,
    MAX(usage_time) AS last_usage,
    DATEDIFF('day', MIN(usage_time), MAX(usage_time)) + 1 AS days_in_use,
    SUM(CASE WHEN TRY_TO_NUMBER(warehouse_id) IS NULL OR TRY_TO_NUMBER(warehouse_id) = 0 THEN 1 ELSE 0 END) AS serverless_calls,
    SUM(CASE WHEN TRY_TO_NUMBER(warehouse_id) > 0 THEN 1 ELSE 0 END) AS compute_calls
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
GROUP BY function_name, model_name
ORDER BY total_credits DESC;

-- View 10: AISQL Model Comparison
-- Purpose: Compare cost/performance across different LLM models
CREATE OR REPLACE VIEW V_AISQL_MODEL_COMPARISON
    COMMENT = 'DEMO: cortex-trail - Model comparison for cost optimization | See deploy_all.sql for expiration'
AS
SELECT
    model_name,
    COUNT(DISTINCT function_name) AS functions_used,
    COUNT(DISTINCT query_id) AS total_calls,
    SUM(token_credits) AS total_credits,
    SUM(tokens) AS total_tokens,
    AVG(token_credits) AS avg_credits_per_call,
    AVG(tokens) AS avg_tokens_per_call,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY token_credits) AS median_credits,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY token_credits) AS p90_credits,
    CASE
        WHEN SUM(tokens) > 0
        THEN SUM(token_credits) / SUM(tokens) * 1000000
        ELSE 0
    END AS cost_per_million_tokens,
    MIN(usage_time) AS first_usage,
    MAX(usage_time) AS last_usage
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    AND model_name IS NOT NULL
GROUP BY model_name
ORDER BY total_credits DESC;

-- View 11: AISQL Daily Trends
-- Purpose: Time-series analysis for trend detection
CREATE OR REPLACE VIEW V_AISQL_DAILY_TRENDS
    COMMENT = 'DEMO: cortex-trail - Daily trends for serverless vs warehouse usage patterns | See deploy_all.sql for expiration'
AS
SELECT
    DATE(usage_time) AS usage_date,
    function_name,
    model_name,
    COUNT(DISTINCT query_id) AS hourly_records,
    SUM(token_credits) AS daily_credits,
    SUM(tokens) AS daily_tokens,
    SUM(CASE WHEN TRY_TO_NUMBER(warehouse_id) IS NULL OR TRY_TO_NUMBER(warehouse_id) = 0 THEN 1 ELSE 0 END) AS serverless_calls,
    SUM(CASE WHEN TRY_TO_NUMBER(warehouse_id) > 0 THEN 1 ELSE 0 END) AS compute_calls
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE usage_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
GROUP BY DATE(usage_time), function_name, model_name
ORDER BY usage_date DESC, daily_credits DESC;

-- View 12: Query-Level Cost Analysis (NEW in v2.6)
-- Purpose: Identify most expensive individual queries across all services
CREATE OR REPLACE VIEW V_QUERY_COST_ANALYSIS
    COMMENT = 'DEMO: cortex-trail - Most expensive queries across LLM functions and document processing | See deploy_all.sql for expiration'
AS
WITH function_queries AS (
    SELECT
        'LLM Functions' AS service_category,
        query_id,
        function_name AS operation_name,
        model_name,
        token_credits AS credits_used,
        tokens AS units_processed,
        NULL AS page_count,
        NULL AS document_count
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
    WHERE usage_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
),
document_queries AS (
    SELECT
        'Document Processing' AS service_category,
        query_id,
        function_name AS operation_name,
        model_name,
        credits_used,
        NULL AS units_processed,
        page_count,
        document_count
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY
    WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
)
SELECT
    service_category,
    query_id,
    operation_name,
    model_name,
    credits_used,
    units_processed,
    page_count,
    document_count,
    -- Cost efficiency metrics
    CASE
        WHEN units_processed > 0 THEN (credits_used / units_processed) * 1000000
        ELSE NULL
    END AS cost_per_million_units,
    CASE
        WHEN page_count > 0 THEN credits_used / page_count
        ELSE NULL
    END AS cost_per_page,
    ROW_NUMBER() OVER (PARTITION BY service_category ORDER BY credits_used DESC) AS cost_rank
FROM (
    SELECT
        service_category,
        query_id,
        operation_name,
        model_name,
        credits_used,
        units_processed,
        page_count,
        document_count
    FROM function_queries
    UNION ALL
    SELECT
        service_category,
        query_id,
        operation_name,
        model_name,
        credits_used,
        units_processed,
        page_count,
        document_count
    FROM document_queries
)
WHERE credits_used > 0
QUALIFY ROW_NUMBER() OVER (PARTITION BY service_category ORDER BY credits_used DESC) <= 1000
ORDER BY credits_used DESC;

-- ===========================================================================
-- USER ATTRIBUTION VIEWS (NEW in v3.1, UPDATED v3.3)
-- ===========================================================================
-- Purpose: Answer "What users are driving what spend with what features?"
--
-- Attribution Methods (v3.3 - Feb 2026):
-- - Cortex Analyst: USERNAME from CORTEX_ANALYST_USAGE_HISTORY (direct)
-- - Cortex Functions: USER_ID from CORTEX_AISQL_USAGE_HISTORY (GA Dec 2025) + USERS view
-- - Document Processing: QUERY_ID join to QUERY_HISTORY (no USER_ID column in source)
-- - Cortex REST API: USER_ID from CORTEX_REST_API_USAGE_HISTORY + USERS view (tokens only, no credits)
--
-- Important constraints (Snowflake platform limitations):
-- - Cortex Search (daily/hourly aggregates) does not expose query_id/user,
--   so it cannot be attributed to individual users and is excluded from these views.
-- - REST API usage has TOKEN counts but no per-request CREDIT values;
--   use V_METERING_AI_SERVICES to validate total AI_SERVICES credits.
--
-- NOTE: These views must exist before V_CORTEX_DAILY_SUMMARY, which uses them to compute
--       daily_unique_users for some services.

-- View 17: User Spend Attribution (daily grain, per feature/model)
CREATE OR REPLACE VIEW V_USER_SPEND_ATTRIBUTION
    COMMENT = 'DEMO: cortex-trail - User spend attribution across Cortex services (Analyst + Functions + Document Processing) | See deploy_all.sql for expiration'
AS
WITH analyst AS (
    SELECT
        DATE_TRUNC('day', start_time) AS usage_date,
        username AS user_name,
        'Cortex Analyst' AS service_type,
        'Cortex Analyst' AS feature_name,
        CAST(NULL AS VARCHAR(100)) AS model_name,
        SUM(credits) AS credits_used,
        SUM(request_count) AS operations
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
    WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    GROUP BY 1, 2
),
functions_attributed AS (
    -- Modernized (Jan 2026): Uses USER_ID column directly from CORTEX_AISQL_USAGE_HISTORY (GA Dec 2025)
    -- Joins to USERS view instead of QUERY_HISTORY for better performance
    SELECT
        DATE_TRUNC('day', cf.usage_time) AS usage_date,
        u.name AS user_name,
        'Cortex Functions' AS service_type,
        cf.function_name AS feature_name,
        cf.model_name,
        SUM(cf.token_credits) AS credits_used,
        SUM(cf.tokens) AS operations
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY AS cf
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
        ON cf.user_id = u.user_id
    WHERE cf.usage_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    GROUP BY 1, 2, 3, 4, 5
),
document_processing_attributed AS (
    SELECT
        DATE_TRUNC('day', q.start_time) AS usage_date,
        q.user_name,
        'Cortex Document Processing' AS service_type,
        dp.function_name AS feature_name,
        dp.model_name,
        SUM(dp.credits_used) AS credits_used,
        SUM(dp.page_count) AS operations
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY AS dp
    JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY AS q
        ON dp.query_id = q.query_id
    WHERE q.start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    GROUP BY 1, 2, 3, 4, 5
),
rest_api_attributed AS (
    -- REST API: USER_ID from CORTEX_REST_API_USAGE_HISTORY + USERS view
    -- Note: Tracks TOKENS only (no credits column in source view)
    SELECT
        DATE_TRUNC('day', ra.start_time) AS usage_date,
        u.name AS user_name,
        'Cortex REST API' AS service_type,
        'REST API' AS feature_name,
        ra.model_name,
        CAST(0 AS NUMBER(38,6)) AS credits_used,
        SUM(ra.tokens) AS operations
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY AS ra
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
        ON ra.user_id = u.user_id
    WHERE ra.start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    GROUP BY 1, 2, 3, 4, 5
)
SELECT
    usage_date,
    user_name,
    service_type,
    feature_name,
    model_name,
    credits_used,
    operations,
    CASE WHEN operations > 0 THEN credits_used / operations ELSE NULL END AS credits_per_operation
FROM (
    SELECT
        usage_date,
        user_name,
        service_type,
        feature_name,
        model_name,
        credits_used,
        operations
    FROM analyst
    UNION ALL
    SELECT
        usage_date,
        user_name,
        service_type,
        feature_name,
        model_name,
        credits_used,
        operations
    FROM functions_attributed
    UNION ALL
    SELECT
        usage_date,
        user_name,
        service_type,
        feature_name,
        model_name,
        credits_used,
        operations
    FROM document_processing_attributed
    UNION ALL
    SELECT
        usage_date,
        user_name,
        service_type,
        feature_name,
        model_name,
        credits_used,
        operations
    FROM rest_api_attributed
);

-- View 18: User Spend Summary (top users, overall + service mix)
CREATE OR REPLACE VIEW V_USER_SPEND_SUMMARY
    COMMENT = 'DEMO: cortex-trail - User spend summary (top users by total credits) | See deploy_all.sql for expiration'
AS
SELECT
    user_name,
    SUM(credits_used) AS total_credits_used,
    SUM(CASE WHEN service_type = 'Cortex Analyst' THEN credits_used ELSE 0 END) AS analyst_credits_used,
    SUM(CASE WHEN service_type = 'Cortex Functions' THEN credits_used ELSE 0 END) AS functions_credits_used,
    SUM(CASE WHEN service_type = 'Cortex Document Processing' THEN credits_used ELSE 0 END) AS document_processing_credits_used,
    MIN(usage_date) AS first_usage_date,
    MAX(usage_date) AS last_usage_date,
    COUNT(DISTINCT usage_date) AS active_days,
    COUNT(DISTINCT service_type) AS services_used
FROM V_USER_SPEND_ATTRIBUTION
GROUP BY user_name
ORDER BY total_credits_used DESC;

-- View 19: User Feature Usage (user x service x feature x model)
CREATE OR REPLACE VIEW V_USER_FEATURE_USAGE
    COMMENT = 'DEMO: cortex-trail - User feature/model usage breakdown (attributed) | See deploy_all.sql for expiration'
AS
SELECT
    user_name,
    service_type,
    feature_name,
    model_name,
    SUM(credits_used) AS total_credits_used,
    SUM(operations) AS total_operations,
    MIN(usage_date) AS first_usage_date,
    MAX(usage_date) AS last_usage_date
FROM V_USER_SPEND_ATTRIBUTION
GROUP BY user_name, service_type, feature_name, model_name
ORDER BY total_credits_used DESC;

-- View 13: Cortex Daily Summary (Master Rollup)
-- Purpose: Primary view for historical analysis across all services
CREATE OR REPLACE VIEW V_CORTEX_DAILY_SUMMARY
    COMMENT = 'DEMO: cortex-trail - Master daily rollup across all Cortex services for trend analysis | See deploy_all.sql for expiration'
AS
WITH
analyst AS (
    SELECT
        usage_date::DATE AS usage_date,
        service_type,
        COUNT(DISTINCT username) AS daily_unique_users,
        SUM(request_count) AS total_operations,
        SUM(credits) AS total_credits
    FROM V_CORTEX_ANALYST_DETAIL
    GROUP BY usage_date::DATE, service_type
),
search AS (
    -- Important: CORTEX_SEARCH_DAILY_USAGE_HISTORY already includes SERVING and EMBED_TEXT_TOKENS
    -- (CONSUMPTION_TYPE). Do not add serving usage again from CORTEX_SEARCH_SERVING_USAGE_HISTORY.
    SELECT
        usage_date::DATE AS usage_date,
        service_type,
        0 AS daily_unique_users,
        SUM(CASE WHEN consumption_type = 'EMBED_TEXT_TOKENS' THEN COALESCE(tokens, 0) ELSE 0 END) AS total_operations,
        SUM(credits) AS total_credits
    FROM V_CORTEX_SEARCH_DETAIL
    GROUP BY usage_date::DATE, service_type
),
functions_totals AS (
    SELECT
        usage_date::DATE AS usage_date,
        service_type,
        SUM(tokens) AS total_operations,
        SUM(token_credits) AS total_credits
    FROM V_CORTEX_FUNCTIONS_DETAIL
    GROUP BY usage_date::DATE, service_type
),
functions_users AS (
    SELECT
        usage_date::DATE AS usage_date,
        COUNT(DISTINCT user_name) AS daily_unique_users
    FROM V_USER_SPEND_ATTRIBUTION
    WHERE service_type = 'Cortex Functions'
    GROUP BY usage_date::DATE
),
functions AS (
    SELECT
        t.usage_date,
        t.service_type,
        COALESCE(u.daily_unique_users, 0) AS daily_unique_users,
        t.total_operations,
        t.total_credits
    FROM functions_totals AS t
    LEFT JOIN functions_users AS u
        ON t.usage_date = u.usage_date
),
doc_totals AS (
    SELECT
        usage_date::DATE AS usage_date,
        service_type,
        SUM(page_count) AS total_operations,
        SUM(credits_used) AS total_credits
    FROM V_CORTEX_DOCUMENT_PROCESSING_DETAIL
    GROUP BY usage_date::DATE, service_type
),
doc_users AS (
    SELECT
        usage_date::DATE AS usage_date,
        COUNT(DISTINCT user_name) AS daily_unique_users
    FROM V_USER_SPEND_ATTRIBUTION
    WHERE service_type = 'Cortex Document Processing'
    GROUP BY usage_date::DATE
),
doc_processing AS (
    SELECT
        t.usage_date,
        t.service_type,
        COALESCE(u.daily_unique_users, 0) AS daily_unique_users,
        t.total_operations,
        t.total_credits
    FROM doc_totals AS t
    LEFT JOIN doc_users AS u
        ON t.usage_date = u.usage_date
),
fine_tuning AS (
    SELECT
        usage_date::DATE AS usage_date,
        service_type,
        0 AS daily_unique_users,
        SUM(tokens) AS total_operations,
        SUM(token_credits) AS total_credits
    FROM V_CORTEX_FINE_TUNING_DETAIL
    GROUP BY usage_date::DATE, service_type
),
all_services AS (
    SELECT usage_date, service_type, daily_unique_users, total_operations, total_credits FROM analyst
    UNION ALL
    SELECT usage_date, service_type, daily_unique_users, total_operations, total_credits FROM search
    UNION ALL
    SELECT usage_date, service_type, daily_unique_users, total_operations, total_credits FROM functions
    UNION ALL
    SELECT usage_date, service_type, daily_unique_users, total_operations, total_credits FROM doc_processing
    UNION ALL
    SELECT usage_date, service_type, daily_unique_users, total_operations, total_credits FROM fine_tuning
)
SELECT
    usage_date,
    service_type,
    daily_unique_users,
    total_operations,
    total_credits,
    CASE
        WHEN daily_unique_users > 0 THEN total_credits / daily_unique_users
        ELSE 0
    END AS credits_per_user,
    CASE
        WHEN total_operations > 0 THEN total_credits / total_operations
        ELSE 0
    END AS credits_per_operation
FROM all_services
ORDER BY usage_date DESC, total_credits DESC;

-- View 14: Cortex Cost Export (Calculator Input Format)
-- Purpose: Pre-formatted for Streamlit calculator CSV uploads
CREATE OR REPLACE VIEW V_CORTEX_COST_EXPORT
    COMMENT = 'DEMO: cortex-trail - Export-ready format for cost calculator with projected costs | See deploy_all.sql for expiration'
AS
SELECT
    usage_date AS date,
    service_type,
    daily_unique_users,
    daily_unique_users AS weekly_active_users,
    daily_unique_users AS monthly_active_users,
    total_operations,
    total_credits,
    credits_per_user,
    credits_per_operation,
    ROUND(credits_per_user, 4) AS avg_daily_cost_per_user,
    ROUND(credits_per_user * 30, 2) AS projected_monthly_cost_per_user,
    ROUND(total_credits * 30, 2) AS projected_monthly_total_credits
FROM V_CORTEX_DAILY_SUMMARY
-- No date filter here - let the extraction query control the date range
ORDER BY date DESC, total_credits DESC;

-- View 15: Metering AI Services (Aggregate Credit View)
-- Purpose: High-level view of all AI service credits from metering
CREATE OR REPLACE VIEW V_METERING_AI_SERVICES
    COMMENT = 'DEMO: cortex-trail - AI_SERVICES metering rollup for compute vs cloud services credits | See deploy_all.sql for expiration'
AS
SELECT
    usage_date,
    service_type,
    SUM(credits_used) AS total_credits,
    SUM(credits_used_compute) AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_services_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'AI_SERVICES'
    AND usage_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
GROUP BY usage_date, service_type
ORDER BY usage_date DESC;

-- ===========================================================================
-- HISTORICAL SNAPSHOT TABLE
-- ===========================================================================
-- Purpose: Persistent storage for daily snapshots (4-5x faster than querying views)
-- Populated by: TASK_DAILY_CORTEX_SNAPSHOT (runs 3:00 AM Pacific)
--
-- TRANSIENT TABLE (v3.2+): No Fail-safe storage (~14% cost savings)
-- - Data is regenerable from ACCOUNT_USAGE views
-- - Time Travel still works (default 1 day)
-- - Appropriate for demo/non-critical data
--
-- PERFORMANCE NOTE: Clustering Key NOT Recommended for Demo Scale
-- - Clustering only beneficial for tables > 1 TB
-- - Current demo usage: < 1 GB (clustering would waste credits)
-- - If scaling to 1+ TB: Consider CLUSTER BY (usage_date, service_type)
-- - Validate need: SELECT SYSTEM$CLUSTERING_INFORMATION('CORTEX_USAGE_SNAPSHOTS')

CREATE TRANSIENT TABLE IF NOT EXISTS CORTEX_USAGE_SNAPSHOTS (
    snapshot_date DATE NOT NULL,
    service_type VARCHAR(50) NOT NULL,
    usage_date DATE NOT NULL,
    daily_unique_users NUMBER(38,0),
    total_operations NUMBER(38,0),
    total_credits NUMBER(38,6),
    credits_per_user NUMBER(38,6),
    credits_per_operation NUMBER(38,12),
    -- v2.5: AISQL-specific metrics
    function_name VARCHAR(100),
    model_name VARCHAR(100),
    total_tokens NUMBER(38,0),
    cost_per_million_tokens NUMBER(38,6),
    serverless_calls NUMBER(38,0),
    compute_calls NUMBER(38,0),
    -- v2.6: Document processing metrics
    total_pages_processed NUMBER(38,0),
    total_documents_processed NUMBER(38,0),
    credits_per_page NUMBER(38,6),
    credits_per_document NUMBER(38,6),
    inserted_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
    -- Note: No primary key constraint (nullable function_name/model_name columns)
    -- Uniqueness enforced by MERGE statement in TASK_DAILY_CORTEX_SNAPSHOT
)
COMMENT = 'DEMO: cortex-trail - Daily usage snapshots with function/model/document granularity for fast queries | See deploy_all.sql for expiration';

-- ===========================================================================
-- SERVERLESS TASK: DAILY SNAPSHOT CAPTURE
-- ===========================================================================
-- Schedule: Daily at 3:00 AM Pacific (after ACCOUNT_USAGE refresh)
-- Compute: Serverless (Snowflake-managed, no warehouse required)
-- Purpose: Captures previous 2 days of usage into CORTEX_USAGE_SNAPSHOTS table
--
-- COST GUARDRAILS:
-- - USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE: XSMALL (start small)
-- - SERVERLESS_TASK_MAX_STATEMENT_SIZE: SMALL (cost cap for runaway queries)
-- - Expected cost: ~$0.001-0.003/day ($0.03-0.09/month)
-- - Maximum cost with cap: ~$0.01/day ($0.30/month)
-- - Provides 10x safety margin for forgotten demo deployments

CREATE OR REPLACE TASK TASK_DAILY_CORTEX_SNAPSHOT
    SCHEDULE = 'USING CRON 0 3 * * * America/Los_Angeles'
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    SERVERLESS_TASK_MAX_STATEMENT_SIZE = 'SMALL'
    COMMENT = 'DEMO: cortex-trail - Serverless daily snapshot task with cost guardrails (3:00 AM Pacific) | See deploy_all.sql for expiration'
AS
MERGE INTO CORTEX_USAGE_SNAPSHOTS AS target
USING (
    -- General Cortex services (Analyst, Search)
    SELECT
        CURRENT_DATE() AS snapshot_date,
        service_type,
        usage_date,
        daily_unique_users,
        total_operations,
        total_credits,
        credits_per_user,
        credits_per_operation,
        CAST(NULL AS VARCHAR(100)) AS function_name,
        CAST(NULL AS VARCHAR(100)) AS model_name,
        CAST(NULL AS NUMBER(38,0)) AS total_tokens,
        CAST(NULL AS NUMBER(38,6)) AS cost_per_million_tokens,
        CAST(NULL AS NUMBER(38,0)) AS serverless_calls,
        CAST(NULL AS NUMBER(38,0)) AS compute_calls,
        CAST(NULL AS NUMBER(38,0)) AS total_pages_processed,
        CAST(NULL AS NUMBER(38,0)) AS total_documents_processed,
        CAST(NULL AS NUMBER(38,6)) AS credits_per_page,
        CAST(NULL AS NUMBER(38,6)) AS credits_per_document
    FROM V_CORTEX_DAILY_SUMMARY
    WHERE usage_date >= DATEADD('day', -2, CURRENT_DATE())
        AND service_type NOT IN ('AISQL Functions', 'Cortex Document Processing', 'Cortex Fine-tuning')

    UNION ALL

    -- AISQL function-specific data
    SELECT
        CURRENT_DATE() AS snapshot_date,
        'AISQL Functions' AS service_type,
        usage_date,
        0 AS daily_unique_users,  -- Not available in hourly aggregates
        hourly_records AS total_operations,
        daily_credits AS total_credits,
        0 AS credits_per_user,
        CASE WHEN hourly_records > 0 THEN daily_credits / hourly_records ELSE 0 END AS credits_per_operation,
        function_name,
        model_name,
        daily_tokens AS total_tokens,
        CASE WHEN daily_tokens > 0 THEN (daily_credits / daily_tokens) * 1000000 ELSE 0 END AS cost_per_million_tokens,
        serverless_calls,
        compute_calls,
        CAST(NULL AS NUMBER(38,0)) AS total_pages_processed,
        CAST(NULL AS NUMBER(38,0)) AS total_documents_processed,
        CAST(NULL AS NUMBER(38,6)) AS credits_per_page,
        CAST(NULL AS NUMBER(38,6)) AS credits_per_document
    FROM V_AISQL_DAILY_TRENDS
    WHERE usage_date >= DATEADD('day', -2, CURRENT_DATE())

    UNION ALL

    -- Document Processing
    SELECT
        CURRENT_DATE() AS snapshot_date,
        dp.service_type,
        dp.usage_date,
        COUNT(DISTINCT q.user_name) AS daily_unique_users,
        SUM(dp.page_count) AS total_operations,
        SUM(dp.credits_used) AS total_credits,
        0 AS credits_per_user,
        AVG(dp.credits_per_page) AS credits_per_operation,
        dp.function_name,
        dp.model_name,
        CAST(NULL AS NUMBER(38,0)) AS total_tokens,
        CAST(NULL AS NUMBER(38,6)) AS cost_per_million_tokens,
        CAST(NULL AS NUMBER(38,0)) AS serverless_calls,
        CAST(NULL AS NUMBER(38,0)) AS compute_calls,
        SUM(dp.page_count) AS total_pages_processed,
        SUM(dp.document_count) AS total_documents_processed,
        AVG(dp.credits_per_page) AS credits_per_page,
        AVG(dp.credits_per_document) AS credits_per_document
    FROM V_CORTEX_DOCUMENT_PROCESSING_DETAIL AS dp
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY AS q
        ON dp.query_id = q.query_id
    WHERE dp.usage_date >= DATEADD('day', -2, CURRENT_DATE())
    GROUP BY CURRENT_DATE(), dp.service_type, dp.usage_date, dp.function_name, dp.model_name

    UNION ALL

    -- Fine-tuning
    SELECT
        CURRENT_DATE() AS snapshot_date,
        service_type,
        usage_date,
        0 AS daily_unique_users,
        COUNT(*) AS total_operations,
        SUM(token_credits) AS total_credits,
        0 AS credits_per_user,
        AVG(token_credits) AS credits_per_operation,
        CAST(NULL AS VARCHAR(100)) AS function_name,
        model_name,
        SUM(tokens) AS total_tokens,
        AVG(cost_per_million_tokens) AS cost_per_million_tokens,
        CAST(NULL AS NUMBER(38,0)) AS serverless_calls,
        CAST(NULL AS NUMBER(38,0)) AS compute_calls,
        CAST(NULL AS NUMBER(38,0)) AS total_pages_processed,
        CAST(NULL AS NUMBER(38,0)) AS total_documents_processed,
        CAST(NULL AS NUMBER(38,6)) AS credits_per_page,
        CAST(NULL AS NUMBER(38,6)) AS credits_per_document
    FROM V_CORTEX_FINE_TUNING_DETAIL
    WHERE usage_date >= DATEADD('day', -2, CURRENT_DATE())
    GROUP BY CURRENT_DATE(), service_type, usage_date, model_name
) AS source
ON target.snapshot_date = source.snapshot_date
    AND target.service_type = source.service_type
    AND target.usage_date = source.usage_date
    AND COALESCE(target.function_name, '') = COALESCE(source.function_name, '')
    AND COALESCE(target.model_name, '') = COALESCE(source.model_name, '')
WHEN MATCHED THEN
    UPDATE SET
        daily_unique_users = source.daily_unique_users,
        total_operations = source.total_operations,
        total_credits = source.total_credits,
        credits_per_user = source.credits_per_user,
        credits_per_operation = source.credits_per_operation,
        total_tokens = source.total_tokens,
        cost_per_million_tokens = source.cost_per_million_tokens,
        serverless_calls = source.serverless_calls,
        compute_calls = source.compute_calls,
        total_pages_processed = source.total_pages_processed,
        total_documents_processed = source.total_documents_processed,
        credits_per_page = source.credits_per_page,
        credits_per_document = source.credits_per_document,
        inserted_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (snapshot_date, service_type, usage_date, daily_unique_users, total_operations,
            total_credits, credits_per_user, credits_per_operation, function_name, model_name,
            total_tokens, cost_per_million_tokens, serverless_calls, compute_calls,
            total_pages_processed, total_documents_processed, credits_per_page, credits_per_document)
    VALUES (source.snapshot_date, source.service_type, source.usage_date, source.daily_unique_users,
            source.total_operations, source.total_credits, source.credits_per_user, source.credits_per_operation,
            source.function_name, source.model_name, source.total_tokens, source.cost_per_million_tokens,
            source.serverless_calls, source.compute_calls, source.total_pages_processed,
            source.total_documents_processed, source.credits_per_page, source.credits_per_document);

-- Resume the task to activate it (STARTED state)
ALTER TASK TASK_DAILY_CORTEX_SNAPSHOT RESUME;

-- View 16: Cortex Usage History (Snapshot-Backed for Performance)
-- Purpose: Fast queries for Streamlit calculator (reads from snapshot table)
-- Performance: 4-5x faster than querying ACCOUNT_USAGE views directly
CREATE OR REPLACE VIEW V_CORTEX_USAGE_HISTORY
    COMMENT = 'DEMO: cortex-trail - Historical snapshots with trend analysis (optimized for Streamlit calculator) | See deploy_all.sql for expiration'
AS
SELECT
    usage_date AS date,
    service_type,
    daily_unique_users,
    daily_unique_users AS weekly_active_users,
    daily_unique_users AS monthly_active_users,
    total_operations,
    total_credits,
    credits_per_user,
    credits_per_operation,
    ROUND(credits_per_user, 4) AS avg_daily_cost_per_user,
    ROUND(credits_per_user * 30, 2) AS projected_monthly_cost_per_user,
    ROUND(total_credits * 30, 2) AS projected_monthly_total_credits,
    snapshot_date,
    inserted_at,
    -- v2.6: Document processing metrics
    total_pages_processed,
    total_documents_processed,
    credits_per_page,
    credits_per_document,
    -- Trend analysis metrics
    LAG(total_credits, 7) OVER (PARTITION BY service_type ORDER BY usage_date) AS credits_7d_ago,
    ROUND(((total_credits - LAG(total_credits, 7) OVER (PARTITION BY service_type ORDER BY usage_date)) /
           NULLIF(LAG(total_credits, 7) OVER (PARTITION BY service_type ORDER BY usage_date), 0)) * 100, 2) AS credits_wow_growth_pct
FROM CORTEX_USAGE_SNAPSHOTS
ORDER BY date DESC, total_credits DESC;

-- (User attribution views are defined earlier in this script, before V_CORTEX_DAILY_SUMMARY.)

-- ===========================================================================
-- FORECASTING VIEWS + MODEL (NEW in v3.1)
-- ===========================================================================
-- Purpose: Answer "Forecast my current usage out 12 months"
-- Technology: Snowflake ML Forecasting (SNOWFLAKE.ML.FORECAST)
--
-- Note: Model creation requires CREATE SNOWFLAKE.ML.FORECAST privilege in this schema.
-- This script attempts to create the model and forecast view; if privileges/features
-- are unavailable, it will still deploy successfully and create an empty forecast view.

-- View 20: Forecast Training Input (daily credits per service)
CREATE OR REPLACE VIEW V_FORECAST_INPUT
    COMMENT = 'DEMO: cortex-trail - Forecast training input for daily credits by service | See deploy_all.sql for expiration'
AS
SELECT
    service_type,
    usage_date::TIMESTAMP_NTZ AS ts,
    SUM(total_credits) AS y
FROM CORTEX_USAGE_SNAPSHOTS
WHERE usage_date >= DATEADD('day', -365, CURRENT_DATE())
GROUP BY service_type, usage_date;

-- Model + View 21: 12-month forecast (365 daily periods)
BEGIN
    EXECUTE IMMEDIATE $$
        CREATE OR REPLACE SNOWFLAKE.ML.FORECAST CORTEX_USAGE_FORECAST_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_FORECAST_INPUT'),
            SERIES_COLNAME => 'SERVICE_TYPE',
            TIMESTAMP_COLNAME => 'TS',
            TARGET_COLNAME => 'Y',
            CONFIG_OBJECT => {'frequency': '1 day', 'on_error': 'skip'}
        )
        COMMENT = 'DEMO: cortex-trail - Forecast model for daily credits by service | See deploy_all.sql for expiration'
    $$;

    EXECUTE IMMEDIATE $$
        CREATE OR REPLACE VIEW V_USAGE_FORECAST_12M
            COMMENT = 'DEMO: cortex-trail - 12-month daily forecast (ML.FORECAST) for credits by service | See deploy_all.sql for expiration'
        AS
        SELECT
            SERIES::VARCHAR AS service_type,
            TS::DATE AS forecast_date,
            FORECAST::NUMBER(38,6) AS forecast_credits,
            LOWER_BOUND::NUMBER(38,6) AS lower_bound_credits,
            UPPER_BOUND::NUMBER(38,6) AS upper_bound_credits
        FROM TABLE(CORTEX_USAGE_FORECAST_MODEL!FORECAST(FORECASTING_PERIODS => 365))
    $$;
EXCEPTION
    WHEN OTHER THEN
        -- Fallback: deploy an empty view so the rest of the demo still works.
        EXECUTE IMMEDIATE $$
            CREATE OR REPLACE VIEW V_USAGE_FORECAST_12M
                COMMENT = 'DEMO: cortex-trail - 12-month daily forecast view placeholder (model unavailable) | See deploy_all.sql for expiration'
            AS
            SELECT
                CAST(NULL AS VARCHAR) AS service_type,
                CAST(NULL AS DATE) AS forecast_date,
                CAST(NULL AS NUMBER(38,6)) AS forecast_credits,
                CAST(NULL AS NUMBER(38,6)) AS lower_bound_credits,
                CAST(NULL AS NUMBER(38,6)) AS upper_bound_credits
            WHERE 1=0
        $$;
END;

-- ===========================================================================
-- DEPLOYMENT VALIDATION
-- ===========================================================================

-- Verify views created
SELECT
    COUNT(*) AS view_count,
    CASE
        WHEN COUNT(*) = 22 THEN 'SUCCESS: All 22 views created'
        ELSE 'WARNING: Expected 22 views, found ' || COUNT(*)
    END AS validation_status
FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'CORTEX_USAGE'
    AND TABLE_CATALOG = 'SNOWFLAKE_EXAMPLE';

-- Check 2: Verify snapshot table created
SELECT
    COUNT(*) AS table_count,
    CASE
        WHEN COUNT(*) = 1 THEN 'SUCCESS: Snapshot table created'
        ELSE 'WARNING: Snapshot table not found'
    END AS validation_status
FROM SNOWFLAKE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CORTEX_USAGE'
    AND TABLE_CATALOG = 'SNOWFLAKE_EXAMPLE'
    AND TABLE_TYPE = 'BASE TABLE'
    AND TABLE_NAME = 'CORTEX_USAGE_SNAPSHOTS';

-- Verify task created and running
SHOW TASKS LIKE 'TASK_DAILY_CORTEX_SNAPSHOT' IN SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;
-- Expected: STATE = 'started', SCHEDULE shows CRON expression

-- Test data access (empty is normal if no Cortex usage yet)
SELECT
    COUNT(*) AS row_count,
    CASE
        WHEN COUNT(*) > 0 THEN 'SUCCESS: Data available - views are working'
        ELSE 'INFO: No data yet (normal if account has no Cortex usage)'
    END AS data_status
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DAILY_SUMMARY;

-- Test document processing view
SELECT
    COUNT(*) AS row_count,
    'Document processing view accessible' AS validation_step
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_DOCUMENT_PROCESSING_DETAIL;

-- Test query cost analysis view
SELECT
    COUNT(*) AS row_count,
    'Query cost analysis view accessible' AS validation_step
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_QUERY_COST_ANALYSIS;

-- ===========================================================================
-- TROUBLESHOOTING
-- ===========================================================================
--
-- If errors occur during validation:
--
-- 1. "Permission denied" on ACCOUNT_USAGE views
--    -> Need IMPORTED PRIVILEGES on SNOWFLAKE database
--    -> Run as ACCOUNTADMIN: GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;
--
-- 2. Views return no data
--    -> Normal if account has no Cortex usage yet
--    -> Views will populate after using Cortex services (Analyst, Search, Functions)
--
-- 3. Task not starting
--    -> Verify task state: SHOW TASKS IN SCHEMA CORTEX_USAGE;
--    -> If suspended: ALTER TASK TASK_DAILY_CORTEX_SNAPSHOT RESUME;

-- ===========================================================================
-- DEPLOYMENT SUMMARY
-- ===========================================================================
-- Objects Created (v3.3):
--   VIEWS (22): V_CORTEX_ANALYST_DETAIL, V_CORTEX_SEARCH_DETAIL,
--               V_CORTEX_SEARCH_SERVING_DETAIL, V_CORTEX_FUNCTIONS_DETAIL,
--               V_CORTEX_FUNCTIONS_QUERY_DETAIL, V_DOCUMENT_AI_DETAIL,
--               V_CORTEX_DOCUMENT_PROCESSING_DETAIL, V_CORTEX_FINE_TUNING_DETAIL,
--               V_CORTEX_REST_API_DETAIL, V_AISQL_FUNCTION_SUMMARY, V_AISQL_MODEL_COMPARISON,
--               V_AISQL_DAILY_TRENDS, V_QUERY_COST_ANALYSIS, V_CORTEX_DAILY_SUMMARY,
--               V_CORTEX_COST_EXPORT, V_METERING_AI_SERVICES, V_CORTEX_USAGE_HISTORY,
--               V_USER_SPEND_ATTRIBUTION, V_USER_SPEND_SUMMARY, V_USER_FEATURE_USAGE,
--               V_FORECAST_INPUT, V_USAGE_FORECAST_12M
--   TABLES (1): CORTEX_USAGE_SNAPSHOTS (TRANSIENT, snapshot storage)
--   TASKS (1): TASK_DAILY_CORTEX_SNAPSHOT (serverless, 3:00 AM Pacific)
--   MODELS (1, optional): CORTEX_USAGE_FORECAST_MODEL (requires CREATE SNOWFLAKE.ML.FORECAST)
--
-- Next Steps:
--   - Query views: SELECT usage_date, service_type, daily_unique_users, total_operations, total_credits FROM V_CORTEX_DAILY_SUMMARY LIMIT 10
--   - Deploy calculator: Run deploy_all.sql from project root
--   - Export metrics: See sql/02_utilities/export_metrics.sql
