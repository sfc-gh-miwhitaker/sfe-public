# Scenario: Set a Spending Limit

**Goal:** Cap Cortex Code AI credit consumption — either across the account (monthly) or per user (rolling 24h).

**Key decision:** Which limit type fits your scope?

| | Account Budget | Custom Budget | Per-User Daily Limit |
|--|---------------|--------------|---------------------|
| **What it covers** | ALL credits in the account (AI, compute, storage) | Specific warehouses, databases, schemas, or tagged objects | Individual user's AI credit usage on each Cortex Code surface |
| **Tracks AI credits?** | Yes — `AI_SERVICES` is a monitored service type | No — AI credits only appear in the account budget | Yes — estimated AI credits per user |
| **Window** | Monthly (resets 1st of month) | Monthly (resets 1st of month) | Rolling 24 hours |
| **Max instances** | 1 (pre-exists, cannot be created) | Up to 100 | One per user (plus account default) |
| **Automated actions** | Not supported | Supported (stored procedures) | Blocks user at limit; no native warning (see `worksheets/notifications.sql` for custom alerts) |
| **Best for** | Single team / small org / "I just want a monthly cap" | Large orgs tracking multiple teams or projects | Preventing any single user from consuming disproportionate credits |

> **Bottom line:** Use the **account budget** to cap total AI spend. Use **per-user daily limits** to prevent any one user from running away with credits. Use **custom budgets** to track warehouse-level spend per team.

---

## Option A: Account Budget (alert on AI credit spend)

The account budget (`SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET`) pre-exists in every Snowflake account. You activate it and configure notifications.

### 1 — Activate

```sql
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ACTIVATE();
```

### 2 — Set monthly spending limit

```sql
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_SPENDING_LIMIT(1000);
-- Units: Snowflake credits. $2.00/credit on-demand → $1,000 limit = 500 credits
```

> Resets at 12:00 AM UTC on the 1st of each month.

### 3 — Add email notification

```sql
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
    'budgets_email_int',         -- integration name (create first if needed)
    0.8,                         -- threshold: 80% of limit
    'Alert',                     -- level: "Info", "Alert", or "Critical"
    'finops@example.com'         -- email address (must be verified in Snowflake)
);
```

> To create the email integration if you don't have one:
> ```sql
> CREATE NOTIFICATION INTEGRATION budgets_email_int
>   TYPE = EMAIL
>   ENABLED = TRUE
>   ALLOWED_RECIPIENTS = ('finops@example.com');
> ```

### 4 — Check current status

```sql
SELECT SERVICE_TYPE, USAGE_IN_CURRENCY
FROM TABLE(
    SNOWFLAKE.CORE.GET_SERVICE_TYPE_USAGE_V2(
        SERVICE_TYPE => 'AI_SERVICES',
        TIME_LOWER_BOUND => DATE_TRUNC('month', CURRENT_DATE),
        TIME_UPPER_BOUND => CURRENT_TIMESTAMP
    )
);
```

---

## Option B: Custom Budget (cap a team's warehouse costs)

Use this when you want to track the cost of a specific warehouse that your team uses for Cortex Code work — even though AI credits themselves won't appear, warehouse credits for the session will.

### 1 — One-time setup (ACCOUNTADMIN, run once)

```sql
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.BUDGETS;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.BUDGETS TO APPLICATION SNOWFLAKE;
```

### 2 — Create the budget

```sql
CREATE SNOWFLAKE.CORE.BUDGET SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET
    WITH BUDGET_ADMIN = CURRENT_ROLE();
```

### 3 — Set monthly limit

```sql
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!SET_SPENDING_LIMIT(500);
```

### 4 — Add a warehouse to track

```sql
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_RESOURCE(
    SYSTEM$REFERENCE('WAREHOUSE', 'TEAM_WH', 'SESSION', 'APPLYBUDGET')
);
```

**Or use a tag (recommended for multi-object, auto-includes new resources):**

```sql
-- Tag the warehouse
ALTER WAREHOUSE TEAM_WH SET TAG BUDGET_TAG = 'team_budget';

-- Add all tagged objects
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_RESOURCE_TAG(
    SYSTEM$REFERENCE('TAG', 'BUDGET_TAG', 'SESSION', 'APPLYBUDGET')
);
```

### 5 — Add email notification

```sql
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
    'budgets_email_int',
    0.8,
    'Alert',
    'team-lead@example.com'
);
```

### 6 — Verify

```sql
SHOW SNOWFLAKE.CORE.BUDGET INSTANCES IN ACCOUNT;
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!GET_SPENDING_HISTORY(
    TIME_LOWER_BOUND => DATEADD('month', -1, CURRENT_DATE),
    TIME_UPPER_BOUND => CURRENT_TIMESTAMP
);
```

---

## Important: mid-month behavior

| Action | Effect |
|--------|--------|
| Create budget mid-month | Tracks from creation only; no backfill |
| `ADD_RESOURCE` to existing budget | No backfill; tracks from add date |
| `ADD_RESOURCE_TAG` to existing budget | No backfill; tags applied forward |
| Increase spending limit | Takes effect immediately |
| Remove budget | Removes alert; does not affect underlying spending |

---

## Option C: Per-User Daily Limit (cap individual usage)

Per-user daily limits use account or user-level parameters to cap how many estimated AI credits each user can consume in a rolling 24-hour window — separately for CLI and Snowsight.

[Snowflake docs: Cost controls for Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/credit-usage-limit)

### 1 — Set account-wide defaults

```sql
ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
```

### 2 — Override for specific users (optional)

```sql
-- Give a power user a higher limit
ALTER USER power_user SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;
ALTER USER power_user SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;

-- Block a specific user entirely
ALTER USER restricted_user SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 0;
ALTER USER restricted_user SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 0;
```

### 3 — Verify

```sql
SHOW PARAMETERS LIKE 'CORTEX_CODE_%_DAILY_EST_CREDIT_LIMIT_PER_USER' IN ACCOUNT;
```

### 4 — Remove limits

```sql
-- Remove account defaults (restores unlimited)
ALTER ACCOUNT UNSET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER;
ALTER ACCOUNT UNSET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER;

-- Remove per-user override (user falls back to account default)
ALTER USER power_user UNSET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER;
```

> **Important:** Snowflake blocks users at 100% of their limit but sends no warning. Use the notification task in `worksheets/notifications.sql` to alert users before they are blocked.

For a full impact analysis (who would be affected by a proposed limit), see `worksheets/per-user-limits.sql`.

---

## Important: mid-month behavior

| Action | Effect |
|--------|--------|
| Create budget mid-month | Tracks from creation only; no backfill |
| `ADD_RESOURCE` to existing budget | No backfill; tracks from add date |
| `ADD_RESOURCE_TAG` to existing budget | No backfill; tags applied forward |
| Increase spending limit | Takes effect immediately |
| Remove budget | Removes alert; does not affect underlying spending |
| Set per-user daily limit | Takes effect immediately; rolling 24h window |
| Change per-user daily limit | New value applies on next request |

---

## Next steps

| | |
|--|--|
| Want automatic action (not just an alert) when limit is hit | [automate-response.md](automate-response.md) |
| Want proactive alerts before a user is blocked | [get-notified.md](get-notified.md) or `worksheets/notifications.sql` |
| Want Slack/Teams/PagerDuty notification instead of email | [get-notified.md](get-notified.md) |
| Want to audit the budget over time | `worksheets/monitoring.sql` |
| Want to analyze who would be affected by a proposed limit | `worksheets/per-user-limits.sql` |
