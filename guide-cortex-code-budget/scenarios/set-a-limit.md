# Scenario: Set a Monthly Spending Limit

**Goal:** Put a hard cap (with alerts) on Cortex Code AI credit consumption for the month.

**Key decision:** Which budget type fits your scope?

| | Account Budget | Custom Budget |
|--|---------------|--------------|
| **What it covers** | ALL credits in the account (AI, compute, storage) | Specific warehouses, databases, schemas, or tagged objects |
| **Tracks AI credits?** | Yes — `AI_SERVICES` is a monitored service type | No — AI credits only appear in the account budget |
| **Max budgets** | 1 (pre-exists, cannot be created) | Up to 100 |
| **Automated actions** | Not supported | Supported (stored procedures) |
| **Best for** | Single team / small org / "I just want a monthly cap" | Large orgs tracking multiple teams or projects |

> **Bottom line:** If you want to cap Cortex Code AI credit spend specifically, use the **account budget** and filter by `AI_SERVICES`. Custom budgets can cap the *warehouse* Cortex Code runs on, but not the AI tokens themselves.

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

## Next steps

| | |
|--|--|
| Want automatic action (not just an alert) when limit is hit | [automate-response.md](automate-response.md) |
| Want Slack/Teams/PagerDuty notification instead of email | [get-notified.md](get-notified.md) |
| Want to audit the budget over time | `worksheets/monitoring.sql` |
