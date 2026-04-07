/*==============================================================================
  WORKSHEET: Threshold-Based Notifications for Cortex Code

  Purpose:    Set up proactive alerts for Cortex Code spend — both monthly
              budget notifications (Snowflake-native) and per-user daily limit
              approach alerts (custom task + procedure).
  Requires:   ACCOUNTADMIN
  Run in:     Snowsight — paste entire worksheet or run sections individually

  Objects created (Tier 2 only):
    - Schema:    SNOWFLAKE_EXAMPLE.CODE_SPEND_CONTROLS
    - Table:     CORTEX_CODE_LIMIT_ALERTS (audit log)
    - Procedure: CORTEX_CODE_LIMIT_ALERT_CHECK
    - Task:      CORTEX_CODE_LIMIT_ALERT_TASK (serverless, every 15 min)
==============================================================================*/

USE ROLE ACCOUNTADMIN;


/*==============================================================================
  TIER 1: MONTHLY BUDGET NOTIFICATIONS (Snowflake-native)
  Uses the account root budget to send alerts at a configured threshold.
==============================================================================*/


/* ── 1a: Create email notification integration ─────────────────────────────
   Change the email address to your FinOps contact.                          */

CREATE NOTIFICATION INTEGRATION IF NOT EXISTS cortex_code_budget_email_int
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('finops@example.com')
    COMMENT = 'Budget threshold alerts for Cortex Code governance';


/* ── 1b: Activate account budget and set monthly limit ─────────────────── */

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ACTIVATE();
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_SPENDING_LIMIT(1000);


/* ── 1c: Add email notification at 80% threshold ──────────────────────── */

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
    'cortex_code_budget_email_int',
    0.80,
    'Alert',
    'finops@example.com'
);


/* ── 1d: (Optional) Add a second threshold at 95% with Critical severity  */

-- CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
--     'cortex_code_budget_email_int',
--     0.95,
--     'Critical',
--     'finops@example.com'
-- );


/* ── 1e: (Optional) Slack webhook notification ─────────────────────────── */

-- CREATE NOTIFICATION INTEGRATION slack_cortex_budget_int
--     TYPE = WEBHOOK
--     ENABLED = TRUE
--     WEBHOOK_URL = 'https://hooks.slack.com/services/T.../B.../...'
--     WEBHOOK_BODY_TEMPLATE = '{
--         "text": "Cortex Code budget alert: SNOWFLAKE_BUDGET_NAME reached SNOWFLAKE_BUDGET_THRESHOLD_PERCENTAGE% of limit (SNOWFLAKE_BUDGET_SPENT_AMOUNT of SNOWFLAKE_BUDGET_LIMIT_AMOUNT credits)"
--     }';
--
-- CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_WEBHOOK_NOTIFICATION_INTEGRATION(
--     'slack_cortex_budget_int', 0.80, 'Alert'
-- );


/* ── 1f: Verify registered notifications ───────────────────────────────── */

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_NOTIFICATION_INTEGRATIONS();


/* ── 1g: Check current AI_SERVICES spend this month ────────────────────── */

SELECT SERVICE_TYPE, USAGE_IN_CURRENCY
FROM TABLE(
    SNOWFLAKE.CORE.GET_SERVICE_TYPE_USAGE_V2(
        SERVICE_TYPE => 'AI_SERVICES',
        TIME_LOWER_BOUND => DATE_TRUNC('month', CURRENT_DATE),
        TIME_UPPER_BOUND => CURRENT_TIMESTAMP
    )
);


/*==============================================================================
  TIER 2: PER-USER DAILY LIMIT APPROACH ALERTS (custom)
  Snowflake blocks users at their daily limit but sends no warning.
  This section deploys a task that checks usage vs limits and emails a
  notification when any user reaches a configurable threshold (default 80%).
==============================================================================*/


/* ── 2a: Configuration — adjust these values ───────────────────────────── */

SET alert_threshold_pct   = 80;     -- notify at this % of daily limit
SET alert_cooldown_hours  = 4;      -- suppress repeat alerts for N hours
SET task_schedule_minutes = 15;     -- task run interval
SET notification_email    = 'finops@example.com';
SET governance_schema     = 'SNOWFLAKE_EXAMPLE.CODE_SPEND_CONTROLS';


/* ── 2b: Create schema and audit table ─────────────────────────────────── */

CREATE SCHEMA IF NOT EXISTS IDENTIFIER($governance_schema);
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA IDENTIFIER($governance_schema) TO APPLICATION SNOWFLAKE;

CREATE TABLE IF NOT EXISTS IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERTS') (
    user_name       VARCHAR,
    surface         VARCHAR,
    usage_credits   NUMBER(12,4),
    limit_credits   NUMBER(12,4),
    pct_used        NUMBER(5,1),
    alerted_at      TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP
);


/* ── 2c: Create stored procedure ───────────────────────────────────────── */

CREATE OR REPLACE PROCEDURE IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_CHECK') ()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    alert_threshold   FLOAT DEFAULT 80;
    cooldown_hours    INT   DEFAULT 4;
    notif_integration VARCHAR DEFAULT 'cortex_code_budget_email_int';
    notif_email       VARCHAR DEFAULT 'finops@example.com';
    cli_default       FLOAT DEFAULT -1;
    ss_default        FLOAT DEFAULT -1;
    alert_count       INT DEFAULT 0;
    c_users CURSOR FOR
        WITH user_usage AS (
            SELECT USER_ID, 'cli' AS surface,
                   SUM(TOKEN_CREDITS) AS rolling_24h_credits
            FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
            WHERE USAGE_TIME >= DATEADD('hour', -24, CURRENT_TIMESTAMP)
            GROUP BY USER_ID
            UNION ALL
            SELECT USER_ID, 'snowsight' AS surface,
                   SUM(TOKEN_CREDITS) AS rolling_24h_credits
            FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
            WHERE USAGE_TIME >= DATEADD('hour', -24, CURRENT_TIMESTAMP)
            GROUP BY USER_ID
        )
        SELECT u.NAME                           AS user_name,
               uu.surface,
               ROUND(uu.rolling_24h_credits, 4) AS usage_credits,
               CASE uu.surface
                   WHEN 'cli'       THEN :cli_default
                   WHEN 'snowsight' THEN :ss_default
               END                              AS limit_credits,
               ROUND(uu.rolling_24h_credits /
                   NULLIF(CASE uu.surface
                       WHEN 'cli'       THEN :cli_default
                       WHEN 'snowsight' THEN :ss_default
                   END, 0) * 100, 1)            AS pct_used
        FROM user_usage uu
        JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON uu.USER_ID = u.USER_ID
        WHERE CASE uu.surface
                  WHEN 'cli'       THEN :cli_default
                  WHEN 'snowsight' THEN :ss_default
              END > 0
          AND ROUND(uu.rolling_24h_credits /
              NULLIF(CASE uu.surface
                  WHEN 'cli'       THEN :cli_default
                  WHEN 'snowsight' THEN :ss_default
              END, 0) * 100, 1) >= :alert_threshold;
BEGIN
    -- Read account defaults
    LET rs_cli RESULTSET := (
        SHOW PARAMETERS LIKE 'CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER' IN ACCOUNT
    );
    LET df_cli RESULTSET := (SELECT "value"::FLOAT AS v FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    FOR r IN df_cli DO
        cli_default := r.v;
    END FOR;

    LET rs_ss RESULTSET := (
        SHOW PARAMETERS LIKE 'CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER' IN ACCOUNT
    );
    LET df_ss RESULTSET := (SELECT "value"::FLOAT AS v FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
    FOR r IN df_ss DO
        ss_default := r.v;
    END FOR;

    IF (cli_default <= 0 AND ss_default <= 0) THEN
        RETURN 'No positive daily limits configured — nothing to check';
    END IF;

    OPEN c_users;
    FOR rec IN c_users DO
        LET recent_count INT := (
            SELECT COUNT(*)
            FROM SNOWFLAKE_EXAMPLE.CODE_SPEND_CONTROLS.CORTEX_CODE_LIMIT_ALERTS
            WHERE user_name = rec.user_name
              AND surface   = rec.surface
              AND alerted_at >= DATEADD('hour', -1 * :cooldown_hours, CURRENT_TIMESTAMP)
        );
        IF (recent_count = 0) THEN
            INSERT INTO SNOWFLAKE_EXAMPLE.CODE_SPEND_CONTROLS.CORTEX_CODE_LIMIT_ALERTS
                (user_name, surface, usage_credits, limit_credits, pct_used)
            VALUES (rec.user_name, rec.surface, rec.usage_credits,
                    rec.limit_credits, rec.pct_used);

            CALL SYSTEM$SEND_EMAIL(
                :notif_integration,
                :notif_email,
                'Cortex Code limit alert: ' || rec.user_name || ' at ' || rec.pct_used || '% (' || rec.surface || ')',
                'User ' || rec.user_name || ' has used ' || rec.usage_credits ||
                ' of ' || rec.limit_credits || ' credits (' || rec.pct_used ||
                '%) on the ' || rec.surface || ' surface in the last 24 hours.' ||
                CHR(10) || CHR(10) ||
                'Threshold: ' || :alert_threshold || '%' || CHR(10) ||
                'Action: The user will be blocked when they reach 100%. ' ||
                'Consider increasing their limit or reaching out.'
            );

            alert_count := alert_count + 1;
        END IF;
    END FOR;
    CLOSE c_users;

    RETURN alert_count || ' alert(s) sent';
END;
$$;


/* ── 2d: Create serverless task ────────────────────────────────────────── */

CREATE OR REPLACE TASK IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_TASK')
    SCHEDULE = '15 MINUTE'
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    COMMENT = 'Checks rolling 24h Cortex Code usage against per-user daily limits and sends alerts'
AS
    CALL IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_CHECK')();

ALTER TASK IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_TASK') RESUME;


/* ── 2e: Verify deployment ─────────────────────────────────────────────── */

SHOW TASKS LIKE 'CORTEX_CODE_LIMIT_ALERT_TASK' IN SCHEMA IDENTIFIER($governance_schema);

SELECT user_name, surface, usage_credits, limit_credits, pct_used, alerted_at
FROM IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERTS')
ORDER BY alerted_at DESC
LIMIT 10;


/*==============================================================================
  TEARDOWN — Uncomment to remove all objects created by Tier 2.
  Tier 1 budget notifications are not affected.
==============================================================================*/

-- ALTER TASK IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_TASK') SUSPEND;
-- DROP TASK IF EXISTS IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_TASK');
-- DROP PROCEDURE IF EXISTS IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_CHECK') ();
-- DROP TABLE IF EXISTS IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERTS');
-- DROP NOTIFICATION INTEGRATION IF EXISTS cortex_code_budget_email_int;
-- DROP SCHEMA IF EXISTS IDENTIFIER($governance_schema);
