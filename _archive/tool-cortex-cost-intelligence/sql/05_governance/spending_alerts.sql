USE ROLE ACCOUNTADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE TABLE IF NOT EXISTS CORTEX_ALERT_STATE (
    alert_name       VARCHAR(100) NOT NULL,
    alert_month      DATE NOT NULL,
    sent_at          TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    credits_at_alert NUMBER(38,6),
    PRIMARY KEY (alert_name, alert_month)
)
COMMENT = 'DEMO: Cortex Cost Intelligence - Alert dedup state tracking | See deploy_all.sql for expiration';

CREATE OR REPLACE PROCEDURE PROC_SEND_MONTHLY_SPEND_ALERT(P_THRESHOLD FLOAT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_already_sent NUMBER;
    v_credits      NUMBER(38,6);
BEGIN
    SELECT COUNT(*) INTO :v_already_sent
    FROM CORTEX_ALERT_STATE
    WHERE alert_name = 'monthly_cortex_spend'
      AND alert_month = DATE_TRUNC('month', CURRENT_DATE());

    IF (v_already_sent > 0) THEN
        RETURN 'Alert already sent for this month';
    END IF;

    SELECT COALESCE(SUM(total_credits), 0) INTO :v_credits
    FROM V_CORTEX_DAILY_SUMMARY
    WHERE usage_date >= DATE_TRUNC('month', CURRENT_DATE());

    IF (v_credits <= P_THRESHOLD) THEN
        RETURN 'Below threshold. Current: ' || v_credits || ' / ' || P_THRESHOLD;
    END IF;

    INSERT INTO CORTEX_ALERT_STATE (alert_name, alert_month, credits_at_alert)
    VALUES ('monthly_cortex_spend', DATE_TRUNC('month', CURRENT_DATE()), :v_credits);

    RETURN 'ALERT: Monthly Cortex spend (' || v_credits || ' credits) exceeded threshold (' || P_THRESHOLD || ')';
END;
$$;

CREATE OR REPLACE ALERT ALERT_MONTHLY_CORTEX_SPEND
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = 'USING CRON 0 */6 * * * UTC'
    IF (EXISTS (
        SELECT 1
        FROM SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.V_CORTEX_DAILY_SUMMARY
        WHERE usage_date >= DATE_TRUNC('month', CURRENT_DATE())
        HAVING SUM(total_credits) > 1000
    ))
    THEN
        CALL SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.PROC_SEND_MONTHLY_SPEND_ALERT(1000);
