---
name: snowflake-cost-visibility
description: "Guide to foundational Snowflake cost visibility: Budget objects, ACCOUNT_USAGE/METERING_DAILY_HISTORY queries, Resource Monitors, and AI_FUNCTIONS_USER RBAC for new BU governance."
---

# Snowflake Cost Visibility — SE Guide

## Purpose

Covers the four foundational cost controls any Snowflake account should have in place before AI spend begins scaling:
1. Account-level spend alerting via the Budget object
2. `METERING_DAILY_HISTORY` queries for service-type attribution
3. Resource monitor guardrails on individual warehouses
4. `AI_FUNCTIONS_USER` RBAC to gate AI access for new business units

Companion to `guide-cortex-ai-cost-controls` (AI-specific spend and enforcement).

## Architecture

```
README.md  ←  main narrative guide (4 sections)
sql/
  budget_setup.sql          ← create/activate account root budget + notifications
  account_usage_queries.sql ← METERING_DAILY_HISTORY attribution queries
  resource_monitors.sql     ← CREATE RESOURCE MONITOR + warehouse assignment
  ai_functions_user_rbac.sql ← revoke CORTEX_USER / grant AI_FUNCTIONS_USER
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Full narrative guide with prose, decision criteria, SQL cross-refs |
| `sql/budget_setup.sql` | Activate account budget; set limit; wire email/Slack/SNS notifications |
| `sql/account_usage_queries.sql` | Service type breakdown, warehouse attribution, 30-day trend, user spend |
| `sql/resource_monitors.sql` | Create warehouse-level monitor; NOTIFY/SUSPEND triggers; assignment |
| `sql/ai_functions_user_rbac.sql` | New BU RBAC pattern; revoke CORTEX_USER from PUBLIC; bulk grant at scale |

## Snowflake Objects

No objects are deployed by this guide. All SQL is read-only queries or DDL the customer runs manually.

Required read access: `SNOWFLAKE.ACCOUNT_USAGE` (needs `GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE`)
Required DDL role: `ACCOUNTADMIN` for Budget, Resource Monitors, and RBAC changes

## Extension Playbook

### How to add a new notification channel to the account budget

1. Create a notification integration in `sql/budget_setup.sql` for the new channel (email, Slack webhook, SNS queue, Teams webhook).
2. Grant `USAGE ON INTEGRATION <name> TO APPLICATION snowflake` — this step is easy to miss and the budget silently won't send without it.
3. Call `SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_NOTIFICATION_INTEGRATION('<name>')` to attach it.
4. Verify with `CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_NOTIFICATION_INTEGRATIONS()`.
5. Update README section 1 with the new channel and any prerequisites.

### How to extend the RBAC pattern to a new role or BU

1. Decide which database role the new BU needs: `AI_FUNCTIONS_USER` (scalar AI functions only) or `CORTEX_USER` (full Cortex including Agents, Analyst, Search).
2. In `sql/ai_functions_user_rbac.sql`, follow the bulk grant template — loop or batch the `GRANT DATABASE ROLE` statements.
3. Run the verification query at the bottom of the file to confirm the grant landed on the right roles.
4. If the new BU also needs the `USE AI FUNCTIONS` account privilege (required separately), grant it to the functional role, not just the database role.

## Gotchas

- **Resource monitors don't cover AI services or serverless.** Use the Budget object for those. This is the most common misunderstanding — admins create a resource monitor expecting it to catch AI spend, but it only fires on warehouse credit usage.
- **`AI_FUNCTIONS_USER` requires TWO grants.** Users need both the `USE AI FUNCTIONS` account-level privilege AND the `AI_FUNCTIONS_USER` database role. The account privilege is on PUBLIC by default; the database role is not. Granting only one won't work.
- **`METERING_DAILY_HISTORY` has 3-hour latency.** Don't use it for real-time monitoring. It's for trend analysis and attribution.
- **ALTER RESOURCE MONITOR TRIGGERS is NOT additive.** If you ALTER a resource monitor and specify TRIGGERS, it replaces all existing triggers. You must re-include every trigger you want to keep.
- **Budget spending limit is alert-only.** It does not block spend. No warehouse is suspended when the limit is exceeded. Use resource monitors for actual enforcement on warehouse spend.
- **CORTEX_USER grants more than you think.** It covers Agents, Analyst, Search, and CoWork — not just AI Functions. Revoking it from a BU role that only needed AI Functions is the right call, but the blast radius of that revoke needs to be audited first.
