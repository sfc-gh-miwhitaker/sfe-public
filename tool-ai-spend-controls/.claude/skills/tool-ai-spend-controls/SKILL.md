---
name: tool-ai-spend-controls
description: "Cortex AI Functions cost governance toolkit: monitoring, alerts, per-user limits, runaway detection. Use when: AI function costs, cortex cost control, AI spending limits, cortex usage monitoring."
---

# Cortex AI Functions — Cost Governance Toolkit

## Purpose
Notebook + Streamlit dashboard for monitoring and controlling Cortex AI Function spend. Based on the official Snowflake documentation for managing AI function costs with Account Usage. Reads from `CORTEX_AI_FUNCTIONS_USAGE_HISTORY` — no staging tables created.

## Architecture

```
SNOWFLAKE.ACCOUNT_USAGE
├── CORTEX_AI_FUNCTIONS_USAGE_HISTORY ──┐
└── USERS ──────────────────────────────┤
                                        ├── notebook.ipynb (monitoring + governance setup)
                                        └── streamlit_app.py (interactive usage dashboard)

deploy_all.sql ──► schema + notebook + streamlit (from Git stage)
teardown_all.sql ──► drop schema CASCADE + notification integration
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | One-command deploy: schema, notebook, Streamlit from Git stage |
| `teardown_all.sql` | Dependency-ordered cleanup (tasks → alert → procedures → tables → schema) |
| `notebook.ipynb` | SQL-cell notebook: monitoring + governance object setup |
| `streamlit_app.py` | Interactive dashboard: usage by day/week/month/year per user |
| `AGENTS.md` | Per-project AI-pair instructions |

## Snowflake Objects

| Object | Action |
|--------|--------|
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY` | Read |
| `SNOWFLAKE.ACCOUNT_USAGE.USERS` | Read |
| `SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS` schema | Create |
| `SFE_AI_SPEND_CONTROLS_WH` warehouse | Create |
| Notebook + Streamlit | Create from Git stage |

## Extension Playbook: Add a New Monitoring Metric

1. **Notebook**: add a markdown cell with section header, then a SQL cell querying `CORTEX_AI_FUNCTIONS_USAGE_HISTORY`
2. **Streamlit**: add a query function in `streamlit_app.py`, create a new `st.subheader` section in the appropriate tab
3. **Both**: use `CREDITS` for cost metrics, join with `USERS` on `USER_ID` for user names
4. Update the README "What's Inside" table

## Gotchas
- `USER_ID` in the usage view is VARCHAR, not NUMBER — cast when joining
- View latency is up to 60 minutes; running queries update every 30 min (best effort)
- `IS_COMPLETED = FALSE` means the query is still running — filter accordingly for runaway detection
- `METRICS` column is an ARRAY with varying structure (token-based vs page-based)
- The view only includes usage after January 5, 2026
- Notification integrations require ACCOUNTADMIN; email recipients must be verified in Snowsight
