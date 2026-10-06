-- ============================================================
-- Budget Setup: Account Root Budget
-- ============================================================
-- This script activates and configures the SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET
-- that exists in every Snowflake account. It covers:
--   1. Checking current state
--   2. Setting a spending limit
--   3. Setting the notification threshold
--   4. Adding email notifications
--   5. Adding Slack webhook notifications (optional)
--   6. Adding Amazon SNS notifications (optional)
--   7. Verification queries
--
-- Required role: ACCOUNTADMIN (or BUDGET_ADMIN application role on the budget)
-- Email addresses must be verified in Snowflake user profiles before use.
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ── STEP 1: CHECK CURRENT STATE ──────────────────────────────────────────────
-- Run these to see if the budget has already been configured.

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_SPENDING_LIMIT();
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_NOTIFICATION_THRESHOLD();
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_NOTIFICATION_INTEGRATIONS();


-- ── STEP 2: SET SPENDING LIMIT ────────────────────────────────────────────────
-- Replace 1000 with your monthly credit budget or contract entitlement.
-- This is the threshold the budget evaluates against for alert calculations.
-- IMPORTANT: This does NOT block spend. It only triggers alerts.

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_SPENDING_LIMIT(1000);


-- ── STEP 3: SET NOTIFICATION THRESHOLD ───────────────────────────────────────
-- This percentage determines when predictive alerts fire.
-- The alert fires when Snowflake forecasts that end-of-month spend will
-- exceed this percentage of the spending limit.
--
-- Default: 110% (fires when projected spend exceeds limit by 10%).
-- Recommended: 80% gives you an early warning before you hit the ceiling.

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_NOTIFICATION_THRESHOLD(80);

-- Verify the threshold was set:
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_NOTIFICATION_THRESHOLD();


-- ── STEP 4: EMAIL NOTIFICATIONS ──────────────────────────────────────────────
-- Option A: Quick setup — pass email addresses directly (no integration object needed).
-- Replace with verified email addresses from your Snowflake account.

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_EMAIL_NOTIFICATIONS(
    'admin@example.com, finops@example.com'
);

-- Option B: Use an explicit notification integration for more control.
-- Use this when you need to manage allowed recipients centrally or share the
-- integration across multiple budgets.

-- Step B-1: Create the notification integration
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS budget_email_integration
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('admin@example.com', 'finops@example.com');

-- Step B-2: Grant the SNOWFLAKE application permission to use the integration
GRANT USAGE ON INTEGRATION budget_email_integration TO APPLICATION snowflake;

-- Step B-3: Associate with the budget
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_EMAIL_NOTIFICATIONS(
    'budget_email_integration',
    'admin@example.com, finops@example.com'
);


-- ── STEP 5: SLACK WEBHOOK NOTIFICATIONS (OPTIONAL) ───────────────────────────
-- Prerequisites: a Snowflake Secret containing your Slack webhook URL,
-- and a notification integration referencing it.

-- Step 5-1: Create a secret for the Slack webhook URL
-- The webhook URL format is: https://hooks.slack.com/services/...
-- Store only the secret portion (the part after the last slash, if using
-- SNOWFLAKE_WEBHOOK_SECRET as the placeholder).
CREATE OR REPLACE SECRET your_db.your_schema.slack_budget_secret
    TYPE = GENERIC_STRING
    SECRET_STRING = '<your-slack-webhook-secret-token>';

-- Step 5-2: Create the webhook notification integration
CREATE OR REPLACE NOTIFICATION INTEGRATION budget_slack_integration
    ENABLED = TRUE
    TYPE = WEBHOOK
    WEBHOOK_URL = 'https://hooks.slack.com/services/SNOWFLAKE_WEBHOOK_SECRET'
    WEBHOOK_BODY_TEMPLATE = '{"text": "SNOWFLAKE_WEBHOOK_MESSAGE"}'
    WEBHOOK_HEADERS = ('Content-Type' = 'application/json')
    WEBHOOK_SECRET = your_db.your_schema.slack_budget_secret;

-- Step 5-3: Grant the integration, secret, schema, and database to SNOWFLAKE app
GRANT USAGE  ON INTEGRATION budget_slack_integration TO APPLICATION snowflake;
GRANT READ   ON SECRET      your_db.your_schema.slack_budget_secret TO APPLICATION snowflake;
GRANT USAGE  ON SCHEMA      your_db.your_schema   TO APPLICATION snowflake;
GRANT USAGE  ON DATABASE    your_db               TO APPLICATION snowflake;

-- Step 5-4: Associate the integration with the budget
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_NOTIFICATION_INTEGRATION(
    'budget_slack_integration'
);


-- ── STEP 6: AMAZON SNS NOTIFICATIONS (OPTIONAL) ──────────────────────────────
-- Use this for programmatic alerting (e.g., Lambda function triggered by budget alert).

CREATE OR REPLACE NOTIFICATION INTEGRATION budget_sns_integration
    ENABLED = TRUE
    TYPE = QUEUE
    DIRECTION = OUTBOUND
    NOTIFICATION_PROVIDER = AWS_SNS
    AWS_SNS_TOPIC_ARN = '<your-sns-topic-arn>'
    AWS_SNS_ROLE_ARN  = '<your-iam-role-arn>';

GRANT USAGE ON INTEGRATION budget_sns_integration TO APPLICATION snowflake;

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_NOTIFICATION_INTEGRATION(
    'budget_sns_integration'
);


-- ── STEP 7: VERIFICATION ──────────────────────────────────────────────────────

-- Confirm spending limit
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_SPENDING_LIMIT();

-- Confirm notification threshold
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_NOTIFICATION_THRESHOLD();

-- Confirm all notification integrations attached
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_NOTIFICATION_INTEGRATIONS();

-- View notification history (shows past alerts sent)
SELECT
    created,
    status,
    message_source,
    integration_name
FROM TABLE(
    INFORMATION_SCHEMA.NOTIFICATION_HISTORY(
        INTEGRATION_NAME => 'budget_email_integration'
    )
)
ORDER BY created DESC
LIMIT 20;


-- ── OPTIONAL: MUTE NOTIFICATIONS TEMPORARILY ─────────────────────────────────
-- During a planned spike (e.g., month-end batch), you may want to silence alerts.
-- Remember to re-enable.

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_NOTIFICATION_MUTE_FLAG(TRUE);
-- ... do your work ...
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_NOTIFICATION_MUTE_FLAG(FALSE);
