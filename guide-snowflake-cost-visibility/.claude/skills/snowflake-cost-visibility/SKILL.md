---
name: snowflake-cost-visibility
description: "Guide to foundational Snowflake cost visibility: Budget objects, ACCOUNT_USAGE/METERING_DAILY_HISTORY queries, and Resource Monitors. Cortex AI access control is out of scope — see guide-cortex-access-control."
---

# Snowflake Cost Visibility — SE Guide

## Purpose

Covers the three foundational cost controls any Snowflake account should have in place before AI spend begins scaling:

1. Account-level spend alerting via the Budget object
2. `METERING_DAILY_HISTORY` queries for service-type attribution
3. Resource monitor guardrails on individual warehouses

Single thesis: see your credits, then cap them.

**Out of scope on purpose:** Cortex AI access control (`CORTEX_USER`, `AI_FUNCTIONS_USER`,
`CORTEX_AGENT_USER`, `USE AI FUNCTIONS`, per-function grants, model application roles).
That is `guide-cortex-access-control`. README section 4 is a scope note that names the
mechanisms and warns about blast radius — it is not a procedure.

Companion to `guide-cortex-ai-cost-controls` (AI-specific spend and enforcement).

## Architecture

```text
README.md  ←  main narrative guide (3 sections + a scope note)
sql/
  budget_setup.sql          ← create/activate account root budget + notifications
  account_usage_queries.sql ← METERING_DAILY_HISTORY attribution queries
  resource_monitors.sql     ← CREATE RESOURCE MONITOR + warehouse assignment
```

## Key Files

| File | Role |
| ------ | ------ |
| `README.md` | Full narrative guide with prose, decision criteria, SQL cross-refs |
| `sql/budget_setup.sql` | Activate account budget; set limit; wire email/Slack/SNS notifications |
| `sql/account_usage_queries.sql` | Service type breakdown, warehouse attribution, 30-day trend, user spend |
| `sql/resource_monitors.sql` | Create warehouse-level monitor; NOTIFY/SUSPEND triggers; assignment |

## Snowflake Objects

No objects are deployed by this guide. All SQL is read-only queries or DDL the customer runs manually.

Required read access: `SNOWFLAKE.ACCOUNT_USAGE` (needs `GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE`)
Required DDL role: `ACCOUNTADMIN` for Budget and Resource Monitors

## Extension Playbook

### How to add a new notification channel to the account budget

1. Create a notification integration in `sql/budget_setup.sql` for the new channel (email, Slack webhook, SNS queue, Teams webhook).
2. Grant `USAGE ON INTEGRATION <name> TO APPLICATION snowflake` — this step is easy to miss and the budget silently won't send without it.
3. Call `SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_NOTIFICATION_INTEGRATION('<name>')` to attach it.
4. Verify with `CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_NOTIFICATION_INTEGRATIONS()`.
5. Update README section 1 with the new channel and any prerequisites.

### How to extend the RBAC pattern to a new role or BU

Out of scope for this guide — Cortex RBAC moved to `guide-cortex-access-control`. If a request
lands here, point at README section 4 and do that work in the access-control guide instead.
Do not reintroduce grant procedures into this guide's SQL files.

## Gotchas

- **Resource monitors don't cover AI services or serverless.** Use the Budget object to *see* those. This is the most common misunderstanding — admins create a resource monitor expecting it to catch AI spend, but it only fires on warehouse credit usage.
- **The Budget object only alerts on AI spend; it does not cap it.** For per-user AI ceilings use `SNOWFLAKE.CORE.QUOTA` or the `CORTEX_CODE_*_DAILY_EST_CREDIT_LIMIT_PER_USER` parameters. Never write that the Budget object is the *only* mechanism covering AI spend — that is false.
- **`METERING_DAILY_HISTORY` has 3-hour latency.** That figure is specific to this view. Other ACCOUNT_USAGE views differ; there is no single account-wide latency number.
- **ALTER RESOURCE MONITOR TRIGGERS is NOT additive.** If you ALTER a resource monitor and specify TRIGGERS, it replaces all existing triggers. You must re-include every trigger you want to keep.
- **Budget spending limit is alert-only.** It does not block spend. No warehouse is suspended when the limit is exceeded. Use resource monitors for actual enforcement on warehouse spend.
- **Cortex RBAC is not this guide's job.** `CORTEX_USER` blast radius, the two-grant requirement, model application roles, and the secondary-role / `IMPORTED PRIVILEGES` bypasses all live in `guide-cortex-access-control`.

Pair-programmed by SE Community + Cortex Code
