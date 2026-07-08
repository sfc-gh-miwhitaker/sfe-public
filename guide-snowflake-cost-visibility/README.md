![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2026--09--30-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Cost Visibility — Foundations

Before you can govern spend, you have to be able to see it. That sounds obvious, but most Snowflake accounts are running without three of the four capabilities covered here — and the one that's most commonly missing (`AI_FUNCTIONS_USER` RBAC) is the one that matters most once AI usage starts growing.

This guide covers the foundational layer of cost governance in Snowflake:

1. **[Budget object](#1-the-budget-object)** — monthly spend alerting with predictive forecasting
2. **[ACCOUNT_USAGE cost attribution](#2-account_usage-cost-attribution)** — `METERING_DAILY_HISTORY` as the entry point to where credits are going
3. **[Resource monitors](#3-resource-monitors)** — warehouse-level guardrails that can actually suspend warehouses
4. **[AI_FUNCTIONS_USER RBAC](#4-ai_functions_user-rbac--new-bu-governance)** — the access control pattern for governing new teams that need AI functions but not the full Cortex surface

Each section has companion SQL in `sql/`. The SQL is copy-paste ready once you substitute role names and email addresses.

**Audience:** Account administrators, FinOps engineers, and data platform leads who own the Snowflake billing relationship.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-07-08 | **Expires:** 2026-09-30 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

If you're in a hurry, here's the priority order:

| Step | What | SQL file | Time |
|------|------|----------|------|
| 1 | Activate the account budget and add your email | `sql/budget_setup.sql` | 5 min |
| 2 | Run the service-type breakdown query | `sql/account_usage_queries.sql` | 2 min |
| 3 | Create a resource monitor on your largest warehouse | `sql/resource_monitors.sql` | 10 min |
| 4 | Audit current CORTEX_USER grants; apply RBAC if needed | `sql/ai_functions_user_rbac.sql` | 20 min |

Step 4 has the most blast radius. Don't skip the audit query at the top of the file before making changes.

---

## Vocabulary

| Term | Plain-language meaning |
|------|----------------------|
| **ACCOUNT_USAGE views** | Snowflake's audit log for everything that costs credits. Lives in the `SNOWFLAKE` database. Has up to 3-hour latency — always looking at the recent past, not right now. |
| **Budget object** | A first-class Snowflake object that watches spend against a threshold you set, then notifies you when projected spend is on track to exceed it. Resets monthly. Does **not** block spend. |
| **Resource monitor** | A Snowflake object that can suspend warehouses when they reach a credit threshold. Covers warehouses only — not serverless features, not AI services. |
| **CORTEX_USER** | The database role in the `SNOWFLAKE` database that enables access to the full Cortex surface: AI Functions, Agents, Analyst, Search, CoWork. Granted to PUBLIC by default — all users have it unless you change this. |
| **AI_FUNCTIONS_USER** | A narrower database role, GA April 2026. Enables scalar AI Functions (AI_COMPLETE, AI_CLASSIFY, etc.) without granting access to Agents, Analyst, Search, or Fine-tuning. Not granted to PUBLIC by default. |
| **USE AI FUNCTIONS** | An account-level privilege required to call AI Functions. Granted to PUBLIC by default. If you revoke CORTEX_USER from PUBLIC, this privilege alone is not sufficient — users also need AI_FUNCTIONS_USER or CORTEX_USER. |
| **SERVICE_TYPE** | The column in `METERING_DAILY_HISTORY` that tells you what consumed the credits. Key values: `WAREHOUSE_METERING`, `AI_SERVICES`, `AUTO_CLUSTERING`, `SERVERLESS_TASK`, `SEARCH_OPTIMIZATION`. |

---

## Before You Query

Two things that trip up most admins before they get started:

**1. Reading ACCOUNT_USAGE views requires a grant.** If you're not running as `ACCOUNTADMIN`, your role needs:

```sql
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_reporting_role>;
```

Without this, every query in Section 2 returns "object does not exist or not authorized."

**2. The Budget object requires `BUDGET_ADMIN`** or `ACCOUNTADMIN` to configure. The account root budget always exists — it just needs to be activated.

---

## 1. The Budget Object

The Budget object is the right tool for tracking total account spend and getting ahead of overages before they show up on your invoice. It is **not** the right tool for blocking spend — for that, see [Resource Monitors](#3-resource-monitors).

### What it does

- Monitors monthly credit consumption against a threshold you define
- Sends **predictive** alerts — it forecasts end-of-month trajectory, not just current spend. If you're 10 days in and already 60% of the way to the limit, it alerts you before you hit 100%.
- Supports email, Slack, Teams, PagerDuty, Amazon SNS, Azure Event Grid, and Google Cloud Pub/Sub
- Resets automatically at the start of each calendar month

### The account root budget

Every Snowflake account has a budget object called `SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET`. It already exists; it just needs to be configured. You don't create it — you activate it.

```sql
-- Check current state of the account root budget
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_SPENDING_LIMIT();
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_NOTIFICATION_THRESHOLD();
```

If these return empty or null, the budget hasn't been configured yet.

### What to set

**Spending limit** is the credit threshold that triggers alert evaluation. Set it to your monthly credit budget or contract entitlement. The budget doesn't block spend when this is reached — it only alerts. You can set it conservatively.

**Notification threshold** controls when alerts fire. The default fires when projected end-of-month spend is more than 10% above the limit. Set it lower (e.g., 80%) to get earlier warnings:

```sql
-- Fire alert when projected spend is forecast to exceed 80% of the limit
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_NOTIFICATION_THRESHOLD(80);
```

### Notification setup (email)

Email notifications require verified email addresses. Set them up in your Snowflake user profile under **Profile → Notifications** before running the setup below.

See `sql/budget_setup.sql` for the full setup sequence, including Slack webhook and SNS options.

### Decision criteria

| You want to… | Use… |
|---|---|
| Know when total account spend is trending over budget | Budget object |
| Stop a specific warehouse from burning credits | Resource monitor |
| See exactly which service or warehouse spent what | ACCOUNT_USAGE views |
| Gate which users can call AI functions | AI_FUNCTIONS_USER RBAC |

The Budget object answers "are we on track this month?" The ACCOUNT_USAGE views answer "where did the credits go?"

### Key gotcha

The Budget object covers all credit types — warehouse compute, AI services, serverless features, storage — but it only **alerts**. If you're looking for something that suspends warehouses, see Section 3. Resource monitors can suspend warehouses but cannot touch AI or serverless spend. The Budget object is the only native governance mechanism that covers AI services spend.

---

## 2. ACCOUNT_USAGE Cost Attribution

`METERING_DAILY_HISTORY` is the primary view for understanding where credits are going at the service level. It aggregates daily by `SERVICE_TYPE`, so you can break out warehouse compute, AI services, auto-clustering, and serverless costs without writing complex queries.

### The view at a glance

```
SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
```

Key columns:

| Column | What it contains |
|--------|------------------|
| `SERVICE_TYPE` | What consumed the credits (see table below) |
| `USAGE_DATE` | Day the usage occurred |
| `CREDITS_USED` | Total credits (compute + cloud services) |
| `CREDITS_BILLED` | What actually hits your invoice (adjusts for cloud services rebate) |

**Latency: up to 3 hours.** This view is for trend analysis, not real-time monitoring.

### SERVICE_TYPE values you'll see most

| SERVICE_TYPE | What it covers |
|---|---|
| `WAREHOUSE_METERING` | All virtual warehouse compute |
| `AI_SERVICES` | Cortex AI Functions, Cortex Analyst |
| `AUTO_CLUSTERING` | Automatic table reclustering |
| `DYNAMIC_TABLE_MAINTENANCE` | Dynamic Table refresh compute |
| `SERVERLESS_TASK` | Task runs on serverless compute |
| `MATERIALIZED_VIEW` | Materialized view maintenance |
| `SEARCH_OPTIMIZATION` | Search Optimization Service |
| `CORTEX_CODE_CLI` | Cortex Code CLI usage |
| `CORTEX_CODE_SNOWSIGHT` | Cortex Code in Snowsight |
| `SNOWPIPE_STREAMING` | Snowpipe Streaming ingestion |
| `REPLICATION` | Cross-region data replication |

### The diagnostic query

Start here to understand your account's credit distribution over the last 30 days:

```sql
SELECT
    service_type,
    SUM(credits_used)   AS total_credits_used,
    SUM(credits_billed) AS total_credits_billed
FROM snowflake.account_usage.metering_daily_history
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY service_type
ORDER BY total_credits_billed DESC;
```

This single query tells you what your biggest cost drivers are. Run it before every cost governance conversation.

### Warehouse attribution

`METERING_DAILY_HISTORY` aggregates at the account level. For warehouse-level breakdown, join to `WAREHOUSE_METERING_HISTORY`:

```sql
-- See which warehouses are the biggest spenders this month
SELECT
    warehouse_name,
    SUM(credits_used_compute)        AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_services_credits,
    SUM(credits_used)                AS total_credits
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATE_TRUNC('month', CURRENT_DATE())
GROUP BY warehouse_name
ORDER BY total_credits DESC
LIMIT 20;
```

### User-level attribution

For warehouse spend by user, `QUERY_HISTORY` is the source:

```sql
-- Credits consumed per user this month (warehouse compute only)
SELECT
    user_name,
    warehouse_name,
    COUNT(*)                  AS query_count,
    SUM(credits_used_cloud_services) AS cloud_credits,
    ROUND(SUM(total_elapsed_time) / 1000 / 3600, 2) AS total_hours_elapsed
FROM snowflake.account_usage.query_history
WHERE start_time >= DATE_TRUNC('month', CURRENT_DATE())
  AND execution_status = 'SUCCESS'
  AND warehouse_name IS NOT NULL
GROUP BY user_name, warehouse_name
ORDER BY cloud_credits DESC
LIMIT 30;
```

See `sql/account_usage_queries.sql` for the complete set of attribution queries including 30-day trend and AI services attribution.

### The 30-day trend

The most useful signal for cost governance conversations isn't the current month — it's the month-over-month trend. A flat or declining spend pattern is noise; a consistently rising one is a conversation.

```sql
-- 30-day rolling daily spend by service type
SELECT
    usage_date,
    service_type,
    credits_billed
FROM snowflake.account_usage.metering_daily_history
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY usage_date DESC, credits_billed DESC;
```

---

## 3. Resource Monitors

Resource monitors are the first-line enforcement mechanism for warehouse spend. They can notify you, suspend a warehouse gracefully, or kill it immediately when a credit threshold is hit.

**Critical scope limitation:** Resource monitors work for **warehouses only**. They do not track or stop AI services, serverless features (Snowpipe, dynamic tables, tasks), materialized view maintenance, auto-clustering, or any other serverless compute. For those, the Budget object is the right tool.

### What a resource monitor does

- Sets a credit quota per warehouse (or for all warehouses at the account level)
- Fires triggers at defined percentage thresholds within a billing cycle
- Trigger actions: `NOTIFY`, `SUSPEND` (wait for running queries to finish), `SUSPEND_IMMEDIATE` (kill running queries)
- Resets at the start of each calendar month by default (configurable)

### The typical pattern

The most common configuration is a three-tier trigger: notify early, suspend gracefully at quota, kill at overrun:

```sql
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE RESOURCE MONITOR analytics_wh_monitor
  WITH CREDIT_QUOTA = 500
  TRIGGERS
    ON 75  PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND
    ON 115 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE analytics_wh SET RESOURCE_MONITOR = analytics_wh_monitor;
```

### Account-level vs warehouse-level

| Type | What it covers | When to use |
|------|----------------|-------------|
| Account-level | All warehouses in the account | Overall ceiling; no per-warehouse granularity |
| Warehouse-level | One or more specific warehouses | Per-team or per-workload budgeting |

A warehouse can be assigned to only one resource monitor. Account-level and warehouse-level monitors work independently — if either limit is hit, the warehouse suspends.

### Billing cycle and resets

By default, the credit quota resets at the start of each calendar month. If you want weekly or daily resets, specify `FREQUENCY` and `START_TIMESTAMP`:

```sql
CREATE OR REPLACE RESOURCE MONITOR weekly_dev_monitor
  WITH CREDIT_QUOTA = 100
  FREQUENCY = WEEKLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 80  PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE dev_wh SET RESOURCE_MONITOR = weekly_dev_monitor;
```

### Non-admin users in the notification list

Resource monitor notifications go to account administrators by default. To include non-admin users (e.g., a warehouse owner who isn't an admin), add them with `NOTIFY_USERS`:

```sql
CREATE OR REPLACE RESOURCE MONITOR etl_wh_monitor
  WITH CREDIT_QUOTA = 200
  NOTIFY_USERS = (PIPELINE_OWNER)
  TRIGGERS
    ON 75  PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;
```

Non-admin users must have verified email addresses, and they only receive email notifications (not Snowsight notifications).

### Critical gotcha: ALTER RESOURCE MONITOR TRIGGERS is not additive

If you run `ALTER RESOURCE MONITOR` and include a `TRIGGERS` clause, it **replaces all existing triggers** — it does not add to them. If you forget to re-include your existing triggers, they're gone.

**Always include all triggers you want to keep when altering:**

```sql
-- WRONG — this removes the existing 75% notify trigger
ALTER RESOURCE MONITOR analytics_wh_monitor
  SET CREDIT_QUOTA = 750
  TRIGGERS ON 100 PERCENT DO SUSPEND;

-- CORRECT — re-specify all triggers
ALTER RESOURCE MONITOR analytics_wh_monitor
  SET CREDIT_QUOTA = 750
  TRIGGERS
    ON 75  PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND
    ON 115 PERCENT DO SUSPEND_IMMEDIATE;
```

See `sql/resource_monitors.sql` for complete examples including multi-warehouse assignment and verification queries.

---

## 4. AI_FUNCTIONS_USER RBAC — New BU Governance

When a new business unit gets Snowflake access, they inherit the same AI capabilities as everyone else — because `CORTEX_USER` is granted to the `PUBLIC` role by default, and `PUBLIC` is granted to every user. That's a deliberate Snowflake default designed to make it easy to get started, but it means every new user in your account can immediately call `AI_COMPLETE`, spin up Cortex Agents, query with Cortex Analyst, and more.

For accounts where AI usage is governed and attributed by team, that default needs to change.

### The default state (and why it's a problem)

```
PUBLIC role → SNOWFLAKE.CORTEX_USER database role
           → all users get: AI Functions, Agents, Analyst, Search, CoWork
```

`CORTEX_USER` is broad. It covers:
- All Cortex AI Functions (AI_COMPLETE, AI_CLASSIFY, AI_EXTRACT, AI_FILTER, AI_SENTIMENT, AI_EMBED, AI_PARSE_DOCUMENT, AI_REDACT, AI_TRANSLATE, AI_TRANSCRIBE)
- Cortex Agents
- Cortex Analyst
- Cortex Search
- Snowflake CoWork

If you want a new business unit to use AI Functions — but not run Agents, spin up Search services, or access CoWork — granting `CORTEX_USER` is too broad. `AI_FUNCTIONS_USER` is the right scope.

### AI_FUNCTIONS_USER: what it gates

`AI_FUNCTIONS_USER` (GA April 2, 2026) enables the scalar AI functions listed above. It does **not** grant access to:
- Cortex Agents
- Cortex Analyst
- Cortex Search
- Cortex Fine-tuning
- Snowflake CoWork
- `AI_AGG` and `AI_SUMMARIZE_AGG` (aggregate variants — these require `CORTEX_USER`)

It also **requires** the `USE AI FUNCTIONS` account-level privilege, which is granted to `PUBLIC` by default. So the database role alone is not sufficient without the account privilege.

### The two-grant requirement

A user needs **both**:
1. The `USE AI FUNCTIONS` account-level privilege (or a per-function variant)
2. The `AI_FUNCTIONS_USER` (or `CORTEX_USER`) database role

If the account privilege is still on `PUBLIC` (the default), step 2 is the only change you need for the new BU. If you've locked down the account privilege, you'll need to grant both.

### The new BU governance pattern

This is the recommended sequence for an account that currently has `CORTEX_USER` on `PUBLIC` and wants to apply tighter controls to new business units without disrupting existing users:

```
STEP 1  Audit: who currently has CORTEX_USER (directly or via PUBLIC)?
STEP 2  Decide: should existing roles keep CORTEX_USER, or do they only need AI_FUNCTIONS_USER?
STEP 3  For new BU roles: grant AI_FUNCTIONS_USER instead of CORTEX_USER
STEP 4  If locking down PUBLIC: revoke CORTEX_USER from PUBLIC; grant selectively
STEP 5  Verify: confirm the right roles have the right database roles
```

The audit in Step 1 is critical before revoking anything from `PUBLIC`. Existing workflows that depend on Agents or Analyst will break if `CORTEX_USER` is removed without a replacement grant.

**Minimal pattern — new BU gets AI Functions only, existing users unchanged:**

```sql
USE ROLE ACCOUNTADMIN;

-- Grant AI_FUNCTIONS_USER to the new BU's functional role
-- USE AI FUNCTIONS is still on PUBLIC, so no change needed there
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE new_bu_role;
```

**Full lockdown pattern — remove CORTEX_USER from PUBLIC, grant selectively:**

```sql
USE ROLE ACCOUNTADMIN;

-- Step 1: Remove the broad default
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;

-- Step 2: Grant full Cortex access to roles that need it
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE trusted_data_eng_role;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE cortex_agents_role;

-- Step 3: Grant AI Functions only to the new BU
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE new_bu_role;
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE analyst_role;
```

### Applying at scale: multiple roles and BUs

When you have many roles to update, manual grants don't scale. Use a pattern that generates and executes grants from `SHOW ROLES`:

```sql
-- Identify all roles that should get AI_FUNCTIONS_USER
-- Replace the IN clause with your actual role naming pattern
SHOW ROLES LIKE 'BU_%';

-- For each row returned, execute:
-- GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE <name>;

-- Alternatively, use a stored procedure or scripted loop
-- to apply grants programmatically from a role inventory table
```

For organizations with dozens of roles across multiple BUs, build a governance table:

```sql
-- Example governance table structure
CREATE TABLE IF NOT EXISTS your_db.your_schema.cortex_role_grants (
    role_name       VARCHAR,
    cortex_level    VARCHAR,  -- 'FULL' (CORTEX_USER) or 'AI_FUNCTIONS' (AI_FUNCTIONS_USER)
    granted_by      VARCHAR,
    granted_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    justification   VARCHAR
);
```

Then drive grants from this table instead of ad-hoc `GRANT` statements. This gives you an auditable record of who has what Cortex access and why.

### Per-function privileges (optional, for surgical control)

If a BU only needs `AI_COMPLETE` and `AI_CLASSIFY` but not the full AI Functions surface, use per-function privileges:

```sql
USE ROLE ACCOUNTADMIN;

-- Revoke blanket USE AI FUNCTIONS from PUBLIC (optional — only if you want full lockdown)
REVOKE USE AI FUNCTIONS ON ACCOUNT FROM ROLE PUBLIC;

-- Grant only specific functions to the BU role
GRANT USE AI FUNCTION AI_COMPLETE  ON ACCOUNT TO ROLE limited_bu_role;
GRANT USE AI FUNCTION AI_CLASSIFY  ON ACCOUNT TO ROLE limited_bu_role;

-- Still need the database role
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE limited_bu_role;
```

Per-function privileges and the blanket `USE AI FUNCTIONS` have an OR relationship — a role with the blanket privilege can call all functions regardless of per-function grants. Only use per-function if you're intentionally restricting to a subset.

### Verification

After any RBAC change, verify the actual grant state before assuming it took effect:

```sql
-- Check what database roles PUBLIC has
SHOW GRANTS TO ROLE PUBLIC;

-- Check grants on a specific role
SHOW GRANTS TO ROLE new_bu_role;

-- Find all roles that have CORTEX_USER
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.CORTEX_USER;

-- Find all roles that have AI_FUNCTIONS_USER
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER;
```

See `sql/ai_functions_user_rbac.sql` for the complete pattern including audit queries, the full lockdown sequence, and the governance table template.

---

## Putting It Together

These four capabilities complement each other — they don't overlap. Here's the decision table:

| You want to… | Use… | SQL file |
|---|---|---|
| Know when total monthly spend is trending over budget | Budget object | `budget_setup.sql` |
| See where credits went (by service, warehouse, user) | ACCOUNT_USAGE queries | `account_usage_queries.sql` |
| Stop a specific warehouse at a credit limit | Resource monitor | `resource_monitors.sql` |
| Control which teams can call AI Functions | AI_FUNCTIONS_USER RBAC | `ai_functions_user_rbac.sql` |

The one thing that doesn't fit neatly here: **stopping runaway AI Function calls** (e.g., `AI_COMPLETE` running against a million-row table without a WHERE clause). That's covered in the companion guide: [`guide-cortex-ai-cost-controls`](../guide-cortex-ai-cost-controls/README.md) — specifically the runaway query protection section.

A complete cost governance stack combines the foundational visibility layer in this guide with the AI-specific enforcement patterns in that one.

---

## Related Resources

- [`guide-cortex-ai-cost-controls`](../guide-cortex-ai-cost-controls/README.md) — AI-specific spend: 14 ACCOUNT_USAGE views, tag-based attribution, per-user Cortex Code limits, runaway query protection, anomaly detection
- [Snowflake docs: Monitor credit usage with budgets](https://docs.snowflake.com/en/user-guide/budgets)
- [Snowflake docs: Working with resource monitors](https://docs.snowflake.com/en/user-guide/resource-monitors)
- [Snowflake docs: AI_FUNCTIONS_USER database role](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access)
- [Snowflake docs: METERING_DAILY_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/metering_daily_history)
