---
name: guide-cortex-ai-cost-controls
description: "Cortex AI cost monitoring and enforcement guide. Covers usage views, tag attribution, user-level limits, runaway query protection, account budget, anomaly detection. Triggers: cortex cost, AI spend, usage view, cost monitoring, budget enforcement, runaway query, anomaly detection, tag attribution, credit limit, AI_FUNCTIONS_USER, CORTEX_CODE_DESKTOP_DAILY, SET_SPENDING_LIMIT, metering daily history, AI services credits, cost center, token credits."
---

# Cortex AI Cost Controls Guide

## Purpose

Teach admins — from first principles — how to monitor, attribute, and enforce Cortex AI spend in Snowflake. Written as a narrative guide that builds a mental model before showing the SQL.

## Architecture

```
README.md           → Full narrative (intro → vocabulary → visibility → attribution → limits → runaway → anomaly → sequence)
runaway-queries.md  → Deep-dive: task + procedure pattern for AI Functions runaway detection
sql/                → 7 standalone scripts for copy-paste execution
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Complete guide — reads cover-to-cover |
| `runaway-queries.md` | Extended pattern: task polling CORTEX_AI_FUNCTIONS_USAGE_HISTORY |
| `sql/visibility_queries.sql` | All 13+ usage views with example queries |
| `sql/tag_setup.sql` | Tag creation, application, attribution query |
| `sql/user_limits_cortex_code.sql` | Native parameter limits (3 surfaces) |
| `sql/user_limits_ai_functions.sql` | DIY: limits table + procedure + task |
| `sql/user_limits_agents_si.sql` | Revoke-based per-agent/SI enforcement |
| `sql/runaway_query_protection.sql` | Task polling for in-flight over-budget queries |
| `sql/account_budget.sql` | Budget object: create, limit, resources, notify |

## Extension Playbook

### Adding a new Cortex service to the visibility and enforcement guide

When Snowflake releases a new usage view (e.g., `CORTEX_NEW_SERVICE_USAGE_HISTORY`):

1. Query `SNOWFLAKE.INFORMATION_SCHEMA.COLUMNS` to get the exact column names and types
2. Note the credit column name — it could be `CREDITS`, `TOKEN_CREDITS`, or `CREDITS_USED`
3. Add a numbered section to `sql/visibility_queries.sql` following the existing pattern (header comment, example query, summary aggregation)
4. Add a row to the view catalog table in README.md Section 1
5. Add the new service to the cross-service summary UNION ALL query at the bottom of `visibility_queries.sql`
6. If the service has a dedicated database role for access control, add a row to the enforcement table in README.md Section 3
7. If enforcement is needed, create a new `sql/user_limits_<service>.sql` following the pattern in `user_limits_ai_functions.sql` (limits table + procedure + task)

## Snowflake Objects

No permanent objects created by default. The enforcement SQL scripts create objects in a user-specified schema when the admin chooses to implement them.

## Gotchas

- **Snowflake has no `ON CONFLICT ... DO UPDATE`.** That's PostgreSQL. Use `MERGE` for all upserts (the limits/config seed tables use it).
- **Object privileges grant TO ROLE, never TO USER.** `GRANT/REVOKE USAGE ON AGENT ... TO/FROM ROLE`. Per-user agent enforcement requires per-user roles (see guide-cowork-only-users). The enforcement procedures resolve each user's DEFAULT_ROLE and act on that role via `IDENTIFIER()`.
- **You can't put a subquery where a role identifier goes** in GRANT/REVOKE. Resolve the role name into a variable first, then inject with `IDENTIFIER(:var)`.
- **Inspect the `*_TAGS` array shape before writing attribution queries.** Key names inside the array vary; use `LATERAL FLATTEN` + filter on the tag name rather than positional `[0]:fq.tag.name` access.
- **Credit column naming is inconsistent across views.** `CREDITS` (AI Functions, Analyst, Search), `TOKEN_CREDITS` (Agents, SI, CoCo, Fine-Tuning), `CREDITS_USED` (Document AI, Search Batch), `PTU_CREDITS` (Provisioned Throughput). Always verify before writing queries.
- **CORTEX_ANALYST_USAGE_HISTORY uses `USERNAME`** while every other view uses `USER_NAME`. JOIN conditions will silently return empty if you get this wrong.
- **Tags only attribute forward.** Historical spend before tag application is permanently unattributed. Tag early.
- **CORTEX_AI_FUNCTIONS_USAGE_HISTORY has up to 60-minute latency.** Runaway query detection is a safety net, not a real-time kill switch. Layer with STATEMENT_TIMEOUT_IN_SECONDS for immediate protection.
- **Budget objects require their own schema.** `CREATE SNOWFLAKE.CORE.BUDGET` creates the budget in the specified location — the schema must exist first.
- **AI_FUNCTIONS_USER is a database role, not an account role.** Grant/revoke syntax is `GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE <role>`, not `GRANT ROLE`.
- **CoCo limit parameters use a rolling 24-hour window, not calendar day.** A user blocked at 3 PM won't be unblocked at midnight — they'll be unblocked at 3 PM the next day when their oldest usage rolls off.
- **Revoking CORTEX_USER from PUBLIC requires three statements.** Just revoking the database role isn't enough — you also need to revoke `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE` and `USE AI FUNCTIONS ON ACCOUNT` from PUBLIC. Missing any one leaves a backdoor.
