---
name: tool-cortex-code-costs
description: >
  Cortex Code cost visibility tool for CLI and Snowsight surfaces. Use when customers ask about Cortex Code
  costs, CoCo usage, CLI token consumption, Snowsight IDE usage, model spend, user attribution, cost
  projections, or CORTEX_CODE_CLI_USAGE_HISTORY / CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY.
---

# tool-cortex-code-costs

## Purpose

Two-artifact tool for surfacing Cortex Code usage and costs from both surfaces in `SNOWFLAKE.ACCOUNT_USAGE`:
- **notebook.ipynb** — parameterized analysis notebook (9 Python cells, `source` variable)
- **streamlit_app.py** — interactive Streamlit dashboard with sidebar source picker
- **deploy_all.sql** — one-shot Git-based deploy script

## Architecture

```
SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
    ↓ (direct query, no objects to deploy beyond schema/notebook/streamlit)
notebook.ipynb  →  9 Python cells: config (source selector), daily, weekly, users, hourly, model breakdown, dollar costs, projections, CLI vs Snowsight comparison, model pricing
streamlit_app.py → 4 tabs: Overview (source split + daily + hourly) | Users (+ source breakdown) | Models (+ source breakdown) | Projections
deploy_all.sql → Creates SNOWFLAKE_EXAMPLE.CORTEX_CODE_COSTS schema, notebook, and Streamlit app from GitHub
```

## Key Files

| File | Role |
|------|------|
| `notebook.ipynb` | Snowflake Notebook — import via Snowsight UI or deploy via deploy_all.sql |
| `streamlit_app.py` | Streamlit in Snowflake — paste or deploy via deploy_all.sql |
| `deploy_all.sql` | One-shot deploy script — paste into Snowsight, Run All |
| `README.md` | Quick Start + architecture |
| `AGENTS.md` | Project-specific conventions |

## Snowflake Objects

- **Reads:** `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY`
- **Reads:** `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY`
- **Creates (deploy_all.sql):** `SNOWFLAKE_EXAMPLE.CORTEX_CODE_COSTS` schema + notebook + Streamlit app

## Extension Playbook

### How to add a new metric (e.g., P95 tokens per request)

1. Add a new SQL cell to `notebook.ipynb` with `%%sql -r <new_var>` header
2. Write the query against `CORTEX_CODE_CLI_USAGE_HISTORY`
3. In `streamlit_app.py`, fetch the new metric using `session.sql(...)` in the relevant tab function
4. Add chart/table to the appropriate tab section

### How to add dollar cost conversion for a new AI credit price

1. In `streamlit_app.py`, find the `ai_credit_price` slider in the sidebar
2. The conversion is `credits * ai_credit_price` — all dollar columns derive from this
3. No SQL changes needed; all dollar math is in Python

## Gotchas

- Both views have ~1-2 hour latency from actual usage
- `CREDITS_GRANULAR` is an OBJECT column — use `LATERAL FLATTEN` to get per-model breakdown
- `TOKEN_CREDITS` is already in AI Credits (not Snowflake Credits) — multiply by `$2.00` for on-demand cost
- When `source = 'both'` in the notebook, all queries run against a UNION ALL subquery; the comparison cell (cell 7) always queries both tables independently regardless of source setting
- The Streamlit "Combined" source picker surfaces a CLI vs Snowsight breakdown in the Overview, Users, and Models tabs
- deploy_all.sql uses the shared `SFE_GIT_API_INTEGRATION` and `SFE_DEMOS_REPO` git repository; these are idempotent and safe to re-run
