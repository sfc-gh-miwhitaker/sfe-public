USE ROLE ACCOUNTADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE TABLE IF NOT EXISTS CORTEX_USER_BUDGETS (
    user_name               VARCHAR(256) NOT NULL,
    user_id                 NUMBER,
    monthly_credit_limit    NUMBER(38,6) DEFAULT 100,
    is_active               BOOLEAN DEFAULT TRUE,
    granted_at              TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    revoked_at              TIMESTAMP_LTZ,
    revocation_reason       VARCHAR(500),
    PRIMARY KEY (user_name)
)
COMMENT = 'DEMO: Cortex Cost Intelligence - Per-user AI budget tracking | See deploy_all.sql for expiration';

CREATE OR REPLACE PROCEDURE PROC_GRANT_AI_ACCESS(
    P_USER_NAME VARCHAR,
    P_MONTHLY_LIMIT NUMBER(38,6) DEFAULT 100
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_user_id NUMBER;
BEGIN
    SELECT USER_ID INTO :v_user_id
    FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
    WHERE NAME = :P_USER_NAME
    LIMIT 1;

    MERGE INTO CORTEX_USER_BUDGETS tgt
    USING (SELECT :P_USER_NAME AS user_name) src
    ON tgt.user_name = src.user_name
    WHEN MATCHED THEN
        UPDATE SET
            user_id              = :v_user_id,
            is_active            = TRUE,
            monthly_credit_limit = :P_MONTHLY_LIMIT,
            granted_at           = CURRENT_TIMESTAMP(),
            revoked_at           = NULL,
            revocation_reason    = NULL
    WHEN NOT MATCHED THEN
        INSERT (user_name, user_id, monthly_credit_limit, is_active)
        VALUES (:P_USER_NAME, :v_user_id, :P_MONTHLY_LIMIT, TRUE);

    RETURN 'Access granted to ' || P_USER_NAME || ' with monthly limit of ' || P_MONTHLY_LIMIT || ' credits';
END;
$$;

CREATE OR REPLACE PROCEDURE PROC_REVOKE_AI_ACCESS(
    P_USER_NAME VARCHAR,
    P_REASON VARCHAR DEFAULT 'Budget exceeded'
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    UPDATE CORTEX_USER_BUDGETS
    SET is_active         = FALSE,
        revoked_at        = CURRENT_TIMESTAMP(),
        revocation_reason = :P_REASON
    WHERE user_name = :P_USER_NAME;

    RETURN 'Access revoked for ' || P_USER_NAME || ': ' || P_REASON;
END;
$$;

CREATE OR REPLACE PROCEDURE PROC_CHECK_USER_BUDGETS()
RETURNS TABLE (user_name VARCHAR, monthly_limit NUMBER, current_spend NUMBER, action VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result RESULTSET;
BEGIN
    result := (
        WITH monthly_spend AS (
            SELECT
                u.NAME AS user_name,
                SUM(h.CREDITS) AS current_credits
            FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY h
            JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON h.USER_ID = u.USER_ID
            WHERE h.START_TIME >= DATE_TRUNC('month', CURRENT_TIMESTAMP())
            GROUP BY u.NAME
        )
        SELECT
            b.user_name,
            b.monthly_credit_limit AS monthly_limit,
            COALESCE(s.current_credits, 0) AS current_spend,
            CASE
                WHEN b.is_active AND COALESCE(s.current_credits, 0) > b.monthly_credit_limit
                THEN 'OVER_BUDGET'
                WHEN b.is_active AND COALESCE(s.current_credits, 0) > b.monthly_credit_limit * 0.8
                THEN 'WARNING_80PCT'
                WHEN NOT b.is_active
                THEN 'REVOKED'
                ELSE 'OK'
            END AS action
        FROM CORTEX_USER_BUDGETS b
        LEFT JOIN monthly_spend s ON b.user_name = s.user_name
    );

    FOR rec IN result DO
        IF (rec.action = 'OVER_BUDGET') THEN
            CALL PROC_REVOKE_AI_ACCESS(rec.user_name, 'Monthly budget exceeded: ' || rec.current_spend || '/' || rec.monthly_limit || ' credits');
        END IF;
    END FOR;

    RETURN TABLE(result);
END;
$$;

CREATE OR REPLACE PROCEDURE PROC_RESTORE_MONTHLY_ACCESS()
RETURNS TABLE (user_name VARCHAR, credit_limit NUMBER, action VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result RESULTSET;
BEGIN
    result := (
        SELECT
            user_name,
            monthly_credit_limit AS credit_limit,
            'RESTORED' AS action
        FROM CORTEX_USER_BUDGETS
        WHERE is_active = FALSE
    );

    FOR rec IN result DO
        CALL PROC_GRANT_AI_ACCESS(rec.user_name, rec.credit_limit);
    END FOR;

    RETURN TABLE(result);
END;
$$;

CREATE OR REPLACE TASK TASK_HOURLY_BUDGET_CHECK
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    SCHEDULE = 'USING CRON 0 * * * * UTC'
    COMMENT  = 'DEMO: Cortex Cost Intelligence - Hourly per-user budget enforcement | See deploy_all.sql for expiration'
AS
    CALL PROC_CHECK_USER_BUDGETS();

CREATE OR REPLACE TASK TASK_MONTHLY_ACCESS_RESTORE
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    SCHEDULE = 'USING CRON 0 0 1 * * UTC'
    COMMENT  = 'DEMO: Cortex Cost Intelligence - Monthly budget reset and access restore | See deploy_all.sql for expiration'
AS
    CALL PROC_RESTORE_MONTHLY_ACCESS();
