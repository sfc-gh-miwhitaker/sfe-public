/*==============================================================================
DEPLOY ALL - Cortex Code FinOps Governance Toolkit
Pair-programmed by SE Community + Cortex Code | Expires: 2026-06-05

Deploys:
  - notebook.ipynb  — 3-section governance notebook (analysis, per-user limits, notifications)
  - Notification objects — integration, stored procedure, task, audit table

INSTRUCTIONS: Open in Snowsight → Run All
==============================================================================*/

-- ============================================================================
-- 0. CONFIGURATION — adjust these values before running
-- ============================================================================
SET notification_email    = 'finops@example.com';
SET alert_threshold_pct   = 80;
SET alert_cooldown_hours  = 4;
SET task_schedule_minutes = 15;
SET monthly_budget_limit  = 1000;
SET budget_alert_pct      = 0.80;
SET governance_schema     = 'SNOWFLAKE_EXAMPLE.CODE_SPEND_CONTROLS';

-- ============================================================================
-- 1. EXPIRATION CHECK (informational — warns but does not block)
-- ============================================================================
SELECT
    '2026-06-05'::DATE                                           AS expiration_date,
    CURRENT_DATE()                                               AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-06-05'::DATE)          AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-06-05'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-06-05'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-06-05'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-06-05'::DATE) || ' days remaining'
    END AS tool_status;

-- ============================================================================
-- 2. PREREQUISITE CHECK
-- The notebook reads SNOWFLAKE.ACCOUNT_USAGE. If your role does not yet have
-- IMPORTED PRIVILEGES on the SNOWFLAKE database, run this once as ACCOUNTADMIN:
--
--   GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE SYSADMIN;
--
-- ============================================================================

-- ============================================================================
-- 3. SHARED INFRASTRUCTURE (ACCOUNTADMIN required for API integration)
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/sfe-public')
    ENABLED = TRUE
    COMMENT = 'Shared Git integration for sfe-public monorepo | Author: SE Community';

-- ============================================================================
-- 4. WAREHOUSE + DATABASE (SYSADMIN)
-- ============================================================================
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE demonstration projects and tools | Author: SE Community';

CREATE WAREHOUSE IF NOT EXISTS SFE_TOOLS_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 120
    COMMENT = 'Shared warehouse for Snowflake Tools Collection | Author: SE Community';

USE WAREHOUSE SFE_TOOLS_WH;

-- ============================================================================
-- 5. GIT REPOSITORY (shared across all sfe-public projects)
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
    COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
    API_INTEGRATION = SFE_GIT_API_INTEGRATION
    ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git'
    COMMENT = 'Shared monorepo Git repository | Author: SE Community';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;

-- ============================================================================
-- 6. GOVERNANCE SCHEMA
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE SCHEMA IF NOT EXISTS IDENTIFIER($governance_schema)
    COMMENT = 'TOOL: Cortex Code FinOps governance objects (Expires: 2026-06-05)';

GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA IDENTIFIER($governance_schema) TO APPLICATION SNOWFLAKE;

USE SCHEMA IDENTIFIER($governance_schema);

-- ============================================================================
-- 7. DEPLOY NOTEBOOK
-- ============================================================================
CREATE OR REPLACE NOTEBOOK IDENTIFIER($governance_schema || '.CODE_SPEND_CONTROLS_NOTEBOOK')
    FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/tool-code-spend-controls/'
    MAIN_FILE = 'notebook.ipynb'
    QUERY_WAREHOUSE = SFE_TOOLS_WH
    COMMENT = 'TOOL: Cortex Code FinOps governance notebook (Expires: 2026-06-05)';

ALTER NOTEBOOK IDENTIFIER($governance_schema || '.CODE_SPEND_CONTROLS_NOTEBOOK')
    ADD LIVE VERSION FROM LAST;

-- ============================================================================
-- 8. NOTIFICATION INTEGRATION
-- ============================================================================
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS cortex_code_budget_email_int
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ($notification_email)
    COMMENT = 'Budget threshold alerts for Cortex Code governance';

-- ============================================================================
-- 9. ACCOUNT BUDGET NOTIFICATIONS
-- ============================================================================
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ACTIVATE();
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_SPENDING_LIMIT($monthly_budget_limit);
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
    'cortex_code_budget_email_int',
    $budget_alert_pct,
    'Alert',
    $notification_email
);

-- ============================================================================
-- 10. PER-USER LIMIT ALERT OBJECTS
-- ============================================================================

-- Audit table
CREATE TABLE IF NOT EXISTS IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERTS') (
    user_name       VARCHAR,
    surface         VARCHAR,
    usage_credits   NUMBER(12,4),
    limit_credits   NUMBER(12,4),
    pct_used        NUMBER(5,1),
    alerted_at      TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP
);

-- Stored procedure
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

-- Serverless task
CREATE OR REPLACE TASK IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_TASK')
    SCHEDULE = $task_schedule_minutes || ' MINUTE'
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    COMMENT = 'Checks rolling 24h Cortex Code usage against per-user daily limits and sends alerts'
AS
    CALL IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_CHECK')();

ALTER TASK IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_TASK') RESUME;

-- ============================================================================
-- 11. DEPLOYMENT SUMMARY
-- ============================================================================
SELECT
    'Deployment complete!' AS status,
    'Snowsight > Projects > Notebooks > CODE_SPEND_CONTROLS_NOTEBOOK' AS notebook,
    $notification_email AS alert_email,
    $alert_threshold_pct || '% of daily limit' AS alert_threshold,
    $monthly_budget_limit || ' credits/month' AS budget_limit,
    CURRENT_TIMESTAMP() AS completed_at;


/*==============================================================================
  TEARDOWN — Uncomment to remove all objects created by this script.
  Budget notifications and per-user limit parameters are NOT affected.
==============================================================================*/

-- ALTER TASK IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_TASK') SUSPEND;
-- DROP TASK IF EXISTS IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_TASK');
-- DROP PROCEDURE IF EXISTS IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERT_CHECK') ();
-- DROP TABLE IF EXISTS IDENTIFIER($governance_schema || '.CORTEX_CODE_LIMIT_ALERTS');
-- DROP NOTEBOOK IF EXISTS IDENTIFIER($governance_schema || '.CODE_SPEND_CONTROLS_NOTEBOOK');
-- DROP NOTIFICATION INTEGRATION IF EXISTS cortex_code_budget_email_int;
-- DROP SCHEMA IF EXISTS IDENTIFIER($governance_schema);
