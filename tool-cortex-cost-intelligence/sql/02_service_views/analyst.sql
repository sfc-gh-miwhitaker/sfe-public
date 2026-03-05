USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE VIEW V_CORTEX_ANALYST_DETAIL
COMMENT = 'DEMO: Cortex Cost Intelligence - Cortex Analyst usage detail | See deploy_all.sql for expiration'
AS
SELECT
    start_time,
    end_time,
    DATE_TRUNC('day', start_time)::DATE AS usage_date,
    username                             AS user_name,
    'Cortex Analyst'                     AS service_type,
    credits,
    request_count                        AS operations,
    CASE WHEN request_count > 0
         THEN ROUND(credits / request_count, 6)
         ELSE 0
    END                                  AS credits_per_operation
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());
