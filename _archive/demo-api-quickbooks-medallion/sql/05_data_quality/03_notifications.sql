/*==============================================================================
05_DATA_QUALITY / 03_NOTIFICATIONS
Database-level notification setup for DQ expectation violations and anomalies.
Supports email and Slack webhook integrations.

When any expectation is violated or anomaly detection fires, Snowflake
automatically sends notifications through the configured integrations.

IMPORTANT: Requires ACCOUNTADMIN for notification integration creation.
Author: SE Community | Expires: 2026-05-01
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- 1. Email Notification Integration
--    Replace the ALLOWED_RECIPIENTS with your actual email addresses.
-------------------------------------------------------------------------------
CREATE OR REPLACE NOTIFICATION INTEGRATION SFE_DQ_EMAIL_INT
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('data-team@example.com')
    COMMENT = 'DEMO: DQ email notifications (Expires: 2026-05-01)';

-------------------------------------------------------------------------------
-- 2. Slack Webhook Notification Integration (optional)
--    Replace the secret string with your actual Slack incoming webhook token.
--    Format: T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
-------------------------------------------------------------------------------
CREATE OR REPLACE SECRET SFE_DQ_SLACK_SECRET
    TYPE = GENERIC_STRING
    SECRET_STRING = 'T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX'  -- pragma: allowlist secret
    COMMENT = 'DEMO: Slack webhook token for DQ alerts (Expires: 2026-05-01)';

CREATE OR REPLACE NOTIFICATION INTEGRATION SFE_DQ_SLACK_INT
    TYPE = WEBHOOK
    ENABLED = TRUE
    WEBHOOK_URL = 'https://hooks.slack.com/services/SNOWFLAKE_WEBHOOK_SECRET'
    WEBHOOK_SECRET = SNOWFLAKE_EXAMPLE.QB_API.SFE_DQ_SLACK_SECRET
    WEBHOOK_BODY_TEMPLATE = '{"text": "SNOWFLAKE_WEBHOOK_MESSAGE"}'
    WEBHOOK_HEADERS = ('Content-Type'='application/json')
    COMMENT = 'DEMO: DQ Slack webhook notifications (Expires: 2026-05-01)';

-------------------------------------------------------------------------------
-- 3. Enable DQ Notifications at the Database Level
--    This tells Snowflake to send notifications whenever:
--    - An expectation is violated
--    - An anomaly is detected
--    Metadata is included so the notification payload contains details
--    about which table, column, and DMF triggered the alert.
-------------------------------------------------------------------------------
ALTER DATABASE SNOWFLAKE_EXAMPLE SET DATA_QUALITY_MONITORING_SETTINGS =
$$
notification:
  enabled: TRUE
  integrations:
    - SFE_DQ_EMAIL_INT
  metadata_included: TRUE
$$;

-- To also include Slack, use this instead:
-- ALTER DATABASE SNOWFLAKE_EXAMPLE SET DATA_QUALITY_MONITORING_SETTINGS =
-- $$
-- notification:
--   enabled: TRUE
--   integrations:
--     - SFE_DQ_EMAIL_INT
--     - SFE_DQ_SLACK_INT
--   metadata_included: TRUE
-- $$;

-------------------------------------------------------------------------------
-- Grant back to SYSADMIN
-------------------------------------------------------------------------------
USE ROLE SYSADMIN;
