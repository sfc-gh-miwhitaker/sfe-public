![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--02--28-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Cost Visibility — Foundations

Before you can govern spend, you have to be able to see it. That sounds obvious, but most Snowflake accounts are running without at least one of the three capabilities covered here — and the gap is usually the third one, the only control that can actually stop a warehouse rather than just tell you about it.

This guide covers the foundational visibility-and-capping layer of cost governance in Snowflake:

1. **[Budget object](#1-the-budget-object)** — monthly spend alerting with predictive forecasting
2. **[ACCOUNT_USAGE cost attribution](#2-account_usage-cost-attribution)** — `METERING_DAILY_HISTORY` as the entry point to where credits are going
3. **[Resource monitors](#3-resource-monitors)** — warehouse-level guardrails that can actually suspend warehouses

One coherent thesis: **see your credits, then cap them.** Deciding *who* may spend credits on AI is access control, not cost visibility, and it is [explicitly out of scope](#4-what-this-guide-does-not-cover-cortex-access-control).

Each section has companion SQL in `sql/`. The SQL is copy-paste ready once you substitute role names and email addresses.

**Audience:** Account administrators, FinOps engineers, and data platform leads who own the Snowflake billing relationship.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-07-08 | **Expires:** 2027-02-28 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

If you're in a hurry, here's the priority order:

| Step | What | SQL file | Time |
| ------ | ------ | ---------- | ------ |
| 1 | Activate the account budget and add your email | `sql/budget_setup.sql` | 5 min |
| 2 | Run the service-type breakdown query | `sql/account_usage_queries.sql` | 2 min |
| 3 | Create a resource monitor on your largest warehouse | `sql/resource_monitors.sql` | 10 min |

All three are additive — none of them takes anything away from anyone. The step that *is* destructive is Cortex RBAC, which this guide deliberately [does not cover](#4-what-this-guide-does-not-cover-cortex-access-control); if it is on your list, sequence it last and read the warning there first.

> **Reading order.** This guide is the foundational visibility layer: budget alerting, usage attribution, and warehouse guardrails. For AI-specific enforcement, AI access control, and compute rightsizing, see the **Govern Snowflake costs and usage** row in the [Start Here index](../README.md#start-here).

---

## Vocabulary

| Term | Plain-language meaning |
| ------ | ---------------------- |
| **ACCOUNT_USAGE views** | Snowflake's audit log for everything that costs credits. Lives in the `SNOWFLAKE` database. Each view documents its own latency \u2014 there is no single account-wide figure \u2014 so you are always looking at the recent past, not right now. `METERING_DAILY_HISTORY` is up to 3 hours behind; check any other view's own doc page. |
| **Budget object** | A first-class Snowflake object that watches spend against a threshold you set, then notifies you when projected spend is on track to exceed it. Resets monthly. Does **not** block spend. |
| **Resource monitor** | A Snowflake object that can suspend warehouses when they reach a credit threshold. Covers warehouses only — not serverless features, not AI services. |
| **SERVICE_TYPE** | The column in `METERING_DAILY_HISTORY` that tells you what consumed the credits. Key values: `WAREHOUSE_METERING`, `AI_SERVICES`, `AUTO_CLUSTERING`, `SERVERLESS_TASK`, `SEARCH_OPTIMIZATION`. |

---

## Before You Query

Two things that trip up most admins before they get started:

**1. Reading ACCOUNT_USAGE views requires a grant.** If you're not running as `ACCOUNTADMIN`, your role needs:

```sql
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_reporting_role>;
```

Without this, every query in Section 2 returns "object does not exist or not authorized."

> `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE` also carries every database role in that database, Cortex roles included. That is an access-control consideration rather than a cost one — noted here only so you know the grant above is broader than "read the usage views."

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
| --- | --- |
| Know when total account spend is trending over budget | Budget object |
| Stop a specific warehouse from burning credits | Resource monitor |
| See exactly which service or warehouse spent what | ACCOUNT_USAGE views |
| Cap AI credits per user | `SNOWFLAKE.CORE.QUOTA` — [out of scope here](#4-what-this-guide-does-not-cover-cortex-access-control) |
| Gate which users can call AI functions at all | Cortex RBAC — [out of scope here](#4-what-this-guide-does-not-cover-cortex-access-control) |

The Budget object answers "are we on track this month?" The ACCOUNT_USAGE views answer "where did the credits go?"

### Key gotcha

The Budget object covers all credit types — warehouse compute, AI services, serverless features, storage — but it only **alerts**. If you want something that suspends warehouses, see Section 3. Resource monitors can suspend warehouses but cannot touch AI or serverless spend.

That asymmetry is why the Budget object is the broadest single lever you have over AI services spend — but it is not the only one, and it is not an enforcement mechanism. Two others cap AI spend rather than merely reporting on it:

| Mechanism | What it does |
| --- | --- |
| `SNOWFLAKE.CORE.QUOTA` | Sets per-user AI credit limits, and can enforce rather than just notify |
| `CORTEX_CODE_*_DAILY_EST_CREDIT_LIMIT_PER_USER` | Caps Cortex Code spend per user, per surface (CLI, Desktop, Snowsight), on a rolling 24-hour window |

So the accurate statement is narrower than "the only mechanism": the Budget object is the only thing here that gives you a single **account-wide predictive alert** spanning every credit type including AI. For per-user AI ceilings, use the two above.

---

## 2. ACCOUNT_USAGE Cost Attribution

`METERING_DAILY_HISTORY` is the primary view for understanding where credits are going at the service level. It aggregates daily by `SERVICE_TYPE`, so you can break out warehouse compute, AI services, auto-clustering, and serverless costs without writing complex queries.

### The view at a glance

```text
SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
```

Key columns:

| Column | What it contains |
| -------- | ------------------ |
| `SERVICE_TYPE` | What consumed the credits (see table below) |
| `USAGE_DATE` | Day the usage occurred |
| `CREDITS_USED` | Total credits (compute + cloud services) |
| `CREDITS_BILLED` | What actually hits your invoice (adjusts for cloud services rebate) |

**Latency: up to 3 hours.** This view is for trend analysis, not real-time monitoring.

### SERVICE_TYPE values you'll see most

| SERVICE_TYPE | What it covers |
| --- | --- |
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
| ------ | ---------------- | ------------- |
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

## 4. What This Guide Does Not Cover: Cortex Access Control

Seeing and capping credits is one problem. Deciding *who is allowed to spend them on
AI in the first place* is a different one, and it is out of scope here.

For the record, the mechanisms are:

| Mechanism | What it gates |
| --- | --- |
| `SNOWFLAKE.CORTEX_USER` database role | The full Cortex surface — AI functions, Agents, Analyst, Search, CoWork, Cortex Code. Granted to `PUBLIC` by default, so every user has it until you change that. |
| `SNOWFLAKE.AI_FUNCTIONS_USER` database role | Scalar AI functions only — no Agents, Analyst, Search, or Fine-tuning. Not granted by default. |
| `USE AI FUNCTIONS` account privilege | AI function calls. Required *in addition to* a qualifying database role, with per-function variants available. |
| Model application roles (`SNOWFLAKE."CORTEX-MODEL-ROLE-*"`) | Which specific LLMs a role may use. Independent of the two above. |

> **If you do go on to change any of this, treat it as the highest-blast-radius step
> in your whole cost-governance sequence — higher than anything in sections 1-3.** Every
> other control in this guide either alerts or throttles; revoking `CORTEX_USER` from
> `PUBLIC` breaks live workflows the moment it lands, and the roles it breaks are not
> obvious in advance. Audit who currently holds it *before* you revoke anything, and
> be aware that the revoke alone does not fully restrict access — secondary roles and
> `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE` both survive it. Do that work from a
> guide that covers it properly; the **Govern Snowflake costs and usage** row in the
> [Start Here index](../README.md#start-here) points at the right one.

---

## Putting It Together

These three capabilities complement each other — they don't overlap. Here's the decision table:

| You want to… | Use… | SQL file |
| --- | --- | --- |
| Know when total monthly spend is trending over budget | Budget object | `budget_setup.sql` |
| See where credits went (by service, warehouse, user) | ACCOUNT_USAGE queries | `account_usage_queries.sql` |
| Stop a specific warehouse at a credit limit | Resource monitor | `resource_monitors.sql` |

Two things sit outside this guide on purpose:

- **Stopping runaway AI function calls** — for example `AI_COMPLETE` running against a million-row table with no `WHERE` clause. Neither a budget nor a resource monitor catches that in time.
- **Deciding who may call AI at all** — Cortex RBAC, covered in section 4's [scope note](#4-what-this-guide-does-not-cover-cortex-access-control).

Both have homes in the **Govern Snowflake costs and usage** row of the [Start Here index](../README.md#start-here). A complete stack combines this guide's visibility-and-capping layer with those.

---

## Related Guides

For guides that work alongside this one, see the [**Start Here** index](../README.md#start-here).

- [Snowflake docs: Monitor credit usage with budgets](https://docs.snowflake.com/en/user-guide/budgets)
- [Snowflake docs: Working with resource monitors](https://docs.snowflake.com/en/user-guide/resource-monitors)
- [Snowflake docs: Understanding overall cost](https://docs.snowflake.com/en/user-guide/cost-understanding-overall)

---

## External References

- [`METERING_DAILY_HISTORY` view](https://docs.snowflake.com/en/sql-reference/account-usage/metering_daily_history)
- [`WAREHOUSE_METERING_HISTORY` view](https://docs.snowflake.com/en/sql-reference/account-usage/warehouse_metering_history)
- [`QUERY_HISTORY` view](https://docs.snowflake.com/en/sql-reference/account-usage/query_history)
- [ACCOUNT_USAGE schema (per-view latency and retention)](https://docs.snowflake.com/en/sql-reference/account-usage)
- [Budgets](https://docs.snowflake.com/en/user-guide/budgets)
- [Resource monitors](https://docs.snowflake.com/en/user-guide/resource-monitors)
- [Controlling cost with quotas (`SNOWFLAKE.CORE.QUOTA`)](https://docs.snowflake.com/en/user-guide/cost-controlling-quotas)
- [Cortex AI privileges and model access](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access)

---

Pair-programmed by SE Community + Cortex Code
