USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_SEARCH_DETAIL
COMMENT = 'DEMO: Cortex Cost Intelligence - Cortex Search daily usage | See deploy_all.sql for expiration'
AS
SELECT
    usage_date::DATE                     AS usage_date,
    database_name,
    schema_name,
    service_name,
    service_id,
    consumption_type,
    'Cortex Search'                      AS service_type,
    model_name,
    credits,
    tokens,
    warehouse_id
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
WHERE usage_date >= DATEADD('day', -90, CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW V_CORTEX_SEARCH_SERVING_DETAIL
COMMENT = 'DEMO: Cortex Cost Intelligence - Cortex Search serving (hourly) usage | See deploy_all.sql for expiration'
AS
SELECT
    start_time,
    end_time,
    DATE_TRUNC('day', start_time)::DATE AS usage_date,
    database_name,
    schema_name,
    service_name,
    service_id,
    'Cortex Search Serving'             AS service_type,
    credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_SERVING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());
