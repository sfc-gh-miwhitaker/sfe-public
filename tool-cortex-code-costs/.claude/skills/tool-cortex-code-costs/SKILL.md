---
name: tool-cortex-code-costs
description: >
  Cortex Code CLI cost visibility tool. Use when customers ask about Cortex Code
  costs, CoCo usage, CLI token consumption, model spend, user attribution, cost
  projections, or CORTEX_CODE_CLI_USAGE_HISTORY.
---

# tool-cortex-code-costs

## Purpose

Two-artifact tool for surfacing Cortex Code CLI usage and costs from `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY`:
- **notebook.ipynb** — grab-and-run analysis notebook (8 SQL cells)
- **streamlit_app.py** — interactive Streamlit dashboard

## Architecture

```
SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    ↓ (direct query, no objects to deploy)
notebook.ipynb  →  8 SQL cells: daily, weekly, users, hourly, model breakdown, dollar costs, model pricing, projections
streamlit_app.py → 4 tabs: Overview | Users | Models | Projections
```

## Key Files

| File | Role |
|------|------|
| `notebook.ipynb` | Snowflake Notebook — import via Snowsight UI |
| `streamlit_app.py` | Streamlit in Snowflake — paste into new SiS app |
| `README.md` | Quick Start + architecture |
| `AGENTS.md` | Project-specific conventions |

## Snowflake Objects

- **Database:** SNOWFLAKE (read-only ACCOUNT_USAGE)
- **Schema:** ACCOUNT_USAGE
- **View:** CORTEX_CODE_CLI_USAGE_HISTORY
- No objects created — zero-deploy tool

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

- `CORTEX_CODE_CLI_USAGE_HISTORY` has ~1-2 hour latency from actual usage
- `CREDITS_GRANULAR` is a VARIANT column — use `LATERAL FLATTEN` to get per-model breakdown
- `TOKEN_CREDITS` is already in AI Credits (not Snowflake Credits) — multiply by `$2.00` for on-demand cost
- Accounts without Cortex Code usage will see empty results; notebook handles this gracefully
