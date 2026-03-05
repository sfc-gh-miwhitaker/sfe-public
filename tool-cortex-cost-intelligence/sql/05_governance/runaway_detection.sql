USE ROLE ACCOUNTADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE OR REPLACE PROCEDURE PROC_MONITOR_AND_CANCEL_RUNAWAY_QUERIES(
    P_CREDIT_THRESHOLD NUMBER DEFAULT 50
)
RETURNS TABLE (
    query_id      VARCHAR,
    user_name     VARCHAR,
    function_name VARCHAR,
    model_name    VARCHAR,
    credits       NUMBER,
    start_time    TIMESTAMP_LTZ,
    action        VARCHAR
)
LANGUAGE SQL
AS
$$
DECLARE
    result RESULTSET;
BEGIN
    result := (
        SELECT
            h.QUERY_ID,
            u.NAME AS user_name,
            h.FUNCTION_NAME,
            h.MODEL_NAME,
            h.CREDITS,
            h.START_TIME,
            'CANCELLED' AS action
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY h
        LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON h.USER_ID = u.USER_ID
        WHERE h.START_TIME >= DATEADD('hour', -48, CURRENT_TIMESTAMP())
          AND h.CREDITS > :P_CREDIT_THRESHOLD
          AND h.IS_COMPLETED = FALSE
    );

    FOR rec IN result DO
        BEGIN
            EXECUTE IMMEDIATE 'SELECT SYSTEM$CANCEL_QUERY(''' || rec.QUERY_ID || ''')';
        EXCEPTION
            WHEN OTHER THEN
                NULL;
        END;
    END FOR;

    RETURN TABLE(result);
END;
$$;

CREATE OR REPLACE TASK TASK_HOURLY_RUNAWAY_DETECTION
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    SCHEDULE = 'USING CRON 0 * * * * UTC'
    COMMENT  = 'DEMO: Cortex Cost Intelligence - Hourly runaway query detection and cancellation | See deploy_all.sql for expiration'
AS
    CALL PROC_MONITOR_AND_CANCEL_RUNAWAY_QUERIES(50);
