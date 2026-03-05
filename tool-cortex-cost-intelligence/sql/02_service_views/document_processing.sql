USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_DOCUMENT_PROCESSING_DETAIL
COMMENT = 'DEMO: Cortex Cost Intelligence - Document processing usage | See deploy_all.sql for expiration'
AS
SELECT
    start_time,
    end_time,
    DATE_TRUNC('day', start_time)::DATE AS usage_date,
    query_id,
    function_name,
    model_name,
    operation_name,
    'Document Processing'               AS service_type,
    credits_used                        AS credits,
    page_count,
    document_count,
    feature_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());
