# Scenario: Get Notified Before You Go Over

**Goal:** Receive an alert — email, Slack, Teams, or PagerDuty — when Cortex Code spend reaches a threshold, so you can act before you hit the limit.

**Prerequisites:** A budget must exist with a spending limit set. See [set-a-limit.md](set-a-limit.md).

---

## Notification channels

| Channel | Integration type | Best for |
|---------|-----------------|----------|
| Email | `TYPE = EMAIL` | Small teams, FinOps lead |
| Slack / Teams / webhook | `TYPE = WEBHOOK` | Engineering team channels |
| AWS SNS | `TYPE = QUEUE`, `QUEUE_TYPE = AWS_SNS` | Enterprise alerting pipelines |
| Azure Event Grid | `TYPE = QUEUE`, `QUEUE_TYPE = AZURE_EVENT_GRID` | Azure-native ops |
| GCP Pub/Sub | `TYPE = QUEUE`, `QUEUE_TYPE = GCP_PUBSUB` | GCP-native ops |

---

## Option A: Email

```sql
-- 1. Create email integration (one-time, ACCOUNTADMIN)
CREATE NOTIFICATION INTEGRATION budgets_email_int
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('finops@example.com', 'team-lead@example.com');

-- 2. Add to budget (run for each threshold you want)
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
    'budgets_email_int',
    0.75,       -- 75%
    'Info',     -- severity level shown in subject line
    'finops@example.com'
);

CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
    'budgets_email_int',
    0.90,
    'Critical',
    'finops@example.com'
);
```

> Severity levels: `Info`, `Alert`, `Critical` — affects email subject only, not behavior.

---

## Option B: Slack webhook

```sql
-- 1. Create webhook integration (ACCOUNTADMIN)
CREATE NOTIFICATION INTEGRATION slack_budget_int
  TYPE = WEBHOOK
  ENABLED = TRUE
  WEBHOOK_URL = 'https://hooks.slack.com/services/T.../B.../...'
  WEBHOOK_SECRET = 'my_slack_secret'  -- optional, for signed requests  # pragma: allowlist secret
  WEBHOOK_BODY_TEMPLATE = '{
    "text": "Budget alert: SNOWFLAKE_BUDGET_NAME reached SNOWFLAKE_BUDGET_THRESHOLD_PERCENTAGE% of limit (SNOWFLAKE_BUDGET_LIMIT_AMOUNT credits used: SNOWFLAKE_BUDGET_SPENT_AMOUNT)"
  }';

-- 2. Add to budget
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_WEBHOOK_NOTIFICATION_INTEGRATION(
    'slack_budget_int',
    0.80,
    'Alert'
);
```

**Available template variables:**

| Variable | Value |
|----------|-------|
| `SNOWFLAKE_BUDGET_NAME` | Name of the budget |
| `SNOWFLAKE_BUDGET_LIMIT_AMOUNT` | Monthly spending limit (credits) |
| `SNOWFLAKE_BUDGET_SPENT_AMOUNT` | Credits spent so far this month |
| `SNOWFLAKE_BUDGET_THRESHOLD_PERCENTAGE` | The threshold that fired (e.g. 80) |

---

## Option C: Microsoft Teams

Same as Slack — use a Teams Incoming Webhook URL:

```sql
CREATE NOTIFICATION INTEGRATION teams_budget_int
  TYPE = WEBHOOK
  ENABLED = TRUE
  WEBHOOK_URL = 'https://your-org.webhook.office.com/webhookb2/...'
  WEBHOOK_BODY_TEMPLATE = '{
    "@type": "MessageCard",
    "text": "Budget alert: SNOWFLAKE_BUDGET_NAME at SNOWFLAKE_BUDGET_THRESHOLD_PERCENTAGE%"
  }';
```

---

## Option D: AWS SNS

```sql
-- 1. Create queue integration
CREATE NOTIFICATION INTEGRATION sns_budget_int
  TYPE = QUEUE
  QUEUE_TYPE = AWS_SNS
  ENABLED = TRUE
  AWS_SNS_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789012:budget-alerts'
  AWS_SNS_ROLE_ARN  = 'arn:aws:iam::123456789012:role/snowflake-sns-role';

-- 2. Retrieve Snowflake's IAM principal for trust policy
DESC INTEGRATION sns_budget_int;
-- Use SF_AWS_IAM_USER_ARN and SF_AWS_EXTERNAL_ID to configure the IAM trust policy

-- 3. Add to budget
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_QUEUE_NOTIFICATION_INTEGRATION(
    'sns_budget_int',
    0.80,
    'Alert'
);
```

---

## Account budget notifications

The same patterns work for the account budget — replace the budget reference:

```sql
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
    'budgets_email_int', 0.80, 'Alert', 'finops@example.com'
);

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_WEBHOOK_NOTIFICATION_INTEGRATION(
    'slack_budget_int', 0.90, 'Critical'
);
```

---

## Verify notifications are registered

```sql
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!GET_NOTIFICATION_INTEGRATIONS();
```

---

## Next steps

| | |
|--|--|
| Notification is not enough — want to auto-resize or suspend a warehouse | [automate-response.md](automate-response.md) |
| Need to audit which integrations are active | `worksheets/monitoring.sql` — `Budget Health` section |
