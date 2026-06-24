---
name: cortex-ai-cost-controls
description: "Project skill for the Cortex AI Cost Controls demo — a Streamlit-in-Snowflake dashboard over live SNOWFLAKE.ACCOUNT_USAGE Cortex usage views. Covers spend visibility, tag attribution, per-user AI Function limits, runaway query protection, and anomaly/budget. Use when working with this project. Triggers: cortex cost dashboard, AI spend streamlit, ACCOUNT_USAGE cortex views, V_AI_USAGE_UNIFIED, AI_FUNCTION_USER_LIMITS, simulate-only enforcement, runaway query, COST_CENTER tag, AI_BUDGET."
---

# Cortex AI Cost Controls

## Purpose
A deployable Streamlit-in-Snowflake dashboard that operationalizes the
guide-cortex-ai-cost-controls patterns over **live** `SNOWFLAKE.ACCOUNT_USAGE`
Cortex usage views: see spend, attribute it, limit it (simulate-only), protect
against runaway queries, and flag anomalies.

## Architecture
`deploy_all.sql` creates shared infra (Git API integration, `SNOWFLAKE_EXAMPLE`
db, warehouse, `SFE_DEMOS_REPO` git repo), `FETCH`es the repo, then runs
`sql/01..05` via `EXECUTE IMMEDIATE FROM` the git stage and publishes the
Streamlit. The app's pages read curated APP views; the Limits and Runaway pages
also `CALL` stored procedures that log decisions to an audit table.

```
ACCOUNT_USAGE (live) → APP views (02) → Streamlit pages (app/)
                          ↑                  ↓ CALL
              limits/config/audit (03) ← procedures + SUSPENDED task
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Single entry point (Snowsight Run All); git-stage orchestration |
| `teardown_all.sql` | Drops schema CASCADE + warehouse |
| `sql/01_setup/01_create_schema.sql` | Schema + `IMPORTED PRIVILEGES` grant to SYSADMIN |
| `sql/02_views/01_app_views.sql` | APP views; `V_AI_USAGE_UNIFIED` normalizes 8 source views |
| `sql/03_enforcement/01_enforcement.sql` | Limits table, config, audit, `V_LIMIT_STATUS`, 2 procs, SUSPENDED task |
| `sql/04_budget/01_account_budget.sql` | Custom `AI_BUDGET` (exception-guarded) |
| `sql/05_streamlit/01_create_streamlit.sql` | `CREATE STREAMLIT ... FROM` git stage |
| `sql/99_optional/01_seed_real_usage.sql` | Optional real AI calls to populate live views |
| `app/streamlit_app.py` | Overview/Spend page |
| `app/pages/{1_Attribution,2_Limits,3_Runaway,4_Anomaly}.py` | The four feature pages |

## Adding a New Cortex Service to the Dashboard

When Snowflake ships a new usage view (e.g. `CORTEX_NEW_SERVICE_USAGE_HISTORY`):

1. `DESCRIBE VIEW SNOWFLAKE.ACCOUNT_USAGE.CORTEX_NEW_SERVICE_USAGE_HISTORY` — note
   the time column, the credit column (`CREDITS`/`TOKEN_CREDITS`/`CREDITS_USED`),
   and the user column (`USER_NAME`/`USERNAME`/`USER_ID`).
2. Add a CTE to `V_AI_USAGE_UNIFIED` in `sql/02_views/01_app_views.sql`, casting
   to the common shape `(usage_day DATE, service VARCHAR, user_name VARCHAR, credits)`.
   If the view exposes only `USER_ID`, `LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS`
   and `QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY deleted_on NULLS FIRST)=1`
   to avoid fanout (see Gotchas). If no user column, `CAST(NULL AS VARCHAR)`.
3. Add it to the final `UNION ALL`.
4. The Overview page picks it up automatically (it groups whatever the view returns).
5. Re-deploy: push to `main`, then re-run `deploy_all.sql` (idempotent).

## Snowflake Objects
- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `CORTEX_AI_COST_CONTROLS`
- Warehouse: `SFE_CORTEX_AI_COST_CONTROLS_WH`
- Views: `V_AI_USAGE_UNIFIED`, `V_AI_SPEND_DAILY`, `V_AI_SERVICE_SUMMARY_30D`,
  `V_AI_SPEND_BY_USER_30D`, `V_AGENT_SPEND_30D`, `V_AGENT_ATTRIBUTION`,
  `V_AI_FUNCTION_USAGE_TODAY_BY_USER`, `V_LIMIT_STATUS`, `V_RUNAWAY_CANDIDATES`
- Tables: `AI_FUNCTION_USER_LIMITS`, `ENFORCEMENT_CONFIG`, `ENFORCEMENT_AUDIT`
- Procedures: `SP_ENFORCE_AI_FUNCTION_LIMITS`, `SP_CANCEL_RUNAWAY`
- Task: `TASK_ENFORCE_AI_FUNCTION_LIMITS` (SUSPENDED), Tag: `COST_CENTER`
- Budget: `AI_BUDGET`, Streamlit: `CORTEX_AI_COST_DASHBOARD`
- All objects carry `COMMENT = 'DEMO: ... (Expires: 2026-07-24)'`

## Gotchas
- **`CORTEX_AI_FUNCTIONS_USAGE_HISTORY` exposes `USER_ID` (NUMBER), not `USER_NAME`.**
  Resolve via `ACCOUNT_USAGE.USERS`. `CORTEX_ANALYST_USAGE_HISTORY` uses `USERNAME`;
  all others use `USER_NAME`.
- **`ACCOUNT_USAGE.USERS` can have multiple rows per `user_id`** (deleted + recreated).
  A naive `LEFT JOIN` can fan out and double-count AI Function credits. Dedupe the
  join (one row per `user_id`) when adding new `USER_ID`-keyed sources.
- **Credit column names vary**: `CREDITS` (AI Functions, Analyst, Search),
  `TOKEN_CREDITS` (Agents, SI, CoCo), `CREDITS_USED` (Document AI). Normalize.
- **Enforcement is simulate-only**; the task ships SUSPENDED. The real REVOKE path
  is commented in `SP_ENFORCE_AI_FUNCTION_LIMITS`. Grants go TO ROLE, never TO USER —
  resolve `DEFAULT_ROLE` and revoke from that role.
- **Use MERGE for upserts** — Snowflake has no `ON CONFLICT`.
- **`SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET` is often not activated** (errors on
  `GET_SPENDING_HISTORY`). The Anomaly page reads the custom `AI_BUDGET` instead.
- **Budget creation needs `ACCOUNTADMIN`**; `04_budget` runs in an exception-guarded
  block so a privilege failure never breaks the one-command deploy.
- **`EXECUTE IMMEDIATE FROM` reads the git stage** — files must be on GitHub `main`
  before `deploy_all.sql` can find them. Local edits validate by running SQL inline.
- **ACCOUNT_USAGE latency is 45–60 min.** "Today"/"in-flight" means "as last reported".
