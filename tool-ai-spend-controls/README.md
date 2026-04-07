![Tool](https://img.shields.io/badge/Type-Tool-blue)
![Deploy](https://img.shields.io/badge/Deploy-deploy__all.sql-green)
![Expires](https://img.shields.io/badge/Expires-2026--05--07-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Cortex AI Functions — Cost Governance Toolkit

**Pair-programmed by SE Community + Cortex Code**
**Created:** 2026-04-07 | **Expires:** 2026-05-07 | **Status:** ACTIVE

Monitor, alert on, and control Cortex AI Function spend (AI_COMPLETE, AI_SUMMARIZE, AI_TRANSLATE, AI_SENTIMENT, etc.) with a Snowflake Notebook and Streamlit dashboard. Based on the official [Managing Cortex AI Function costs with Account Usage](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-func-cost-management) documentation.

> **No support provided.** Reference only. Review and validate before applying to any production workflow.

---

## Quick Start

### Option A — One-Shot Deploy (recommended)

1. In Snowsight: open a new SQL worksheet
2. Paste the contents of [`deploy_all.sql`](deploy_all.sql)
3. Click **Run All**

This creates:
- Notebook `AI_SPEND_CONTROLS_NOTEBOOK` (monitoring + governance setup)
- Streamlit dashboard `AI_SPEND_CONTROLS_DASHBOARD` (interactive usage analytics)
- Schema `SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS`

### Option B — Manual Deploy

#### Step 1 — Grant access (if not already granted)

```sql
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;
```

#### Step 2 — Run the Notebook

1. In Snowsight: **Projects > Notebooks > + Notebook > Import .ipynb**
2. Upload `notebook.ipynb`
3. Select a warehouse and run the monitoring cells (Section A)

#### Step 3 — Deploy the Dashboard

1. In Snowsight: **Projects > Streamlit > + Streamlit App**
2. Paste `streamlit_app.py` contents
3. Select a warehouse

---

## What's Inside

### Notebook — 5 sections

| Section | What it does |
|---------|-------------|
| **A — Usage Monitoring** | Daily credit consumption by function/model, monthly by user, model breakdown |
| **B — Account-Level Alert** | Notification integration, alert state table, threshold procedure, hourly alert |
| **C — Per-User Limits** | AI_FUNCTIONS_USER_ROLE, access control table, grant/revoke procedures, monthly refresh |
| **D — Runaway Detection** | In-flight query detection, automatic cancellation, email alerts with query details |
| **E — Verification** | Status checks for alerts, tasks, access control, and alert history |

### Streamlit Dashboard — 4 tabs

| Tab | What it shows |
|-----|-------------|
| **Overview** | KPI summary, credit trend by day/week/month/year |
| **Users** | Per-user usage broken down by time granularity, top consumers |
| **Functions & Models** | Usage by function and model, cost per function |
| **Cost Controls** | Copy-paste SQL reference for alerts, limits, and runaway detection |

---

## Cost Control Levers

| Lever | Enforcement | Setup | Best For |
|-------|-------------|-------|----------|
| Monthly spending alert | Email notification | 5 min (notebook Section B) | Account-wide monthly cap awareness |
| Per-user spending limits | Hard revocation (hourly) | 10 min (notebook Section C) | Individual credit budgets |
| Runaway query detection | Auto-cancel + email | 5 min (notebook Section D) | Stopping expensive in-flight queries |
| Model selection guidance | Policy / documentation | 2 min (review model breakdown) | Highest leverage, lowest effort |

---

## Prerequisites

- `ACCOUNTADMIN` role (for notification integration, alert creation, role creation)
- `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE` for querying `ACCOUNT_USAGE` views
- At least some Cortex AI Function usage to monitor

---

## Architecture

```
SNOWFLAKE.ACCOUNT_USAGE
├── CORTEX_AI_FUNCTIONS_USAGE_HISTORY ──┐
└── USERS ──────────────────────────────┤
                                        ├── Notebook (monitoring + governance setup)
                                        └── Streamlit (interactive dashboard)

deploy_all.sql ──► schema + notebook + streamlit (from Git stage)
```

---

## Cleanup

If deployed via `deploy_all.sql`:

```sql
-- Suspend tasks and alert first
ALTER TASK IF EXISTS SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS.MONTHLY_AI_FUNCTIONS_ACCESS_REFRESH SUSPEND;
ALTER TASK IF EXISTS SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS.MONITOR_RUNAWAY_AI_QUERIES SUSPEND;
ALTER TASK IF EXISTS SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS.ENFORCE_AI_FUNCTIONS_LIMITS_TASK SUSPEND;
ALTER ALERT IF EXISTS SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS.AI_FUNCTIONS_MONTHLY_SPEND_ALERT SUSPEND;

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.AI_SPEND_CONTROLS CASCADE;
DROP NOTIFICATION INTEGRATION IF EXISTS SFE_AI_COST_ALERTS;
DROP ROLE IF EXISTS AI_FUNCTIONS_USER_ROLE;
DROP WAREHOUSE IF EXISTS SFE_AI_SPEND_CONTROLS_WH;
```

Or run [`teardown_all.sql`](teardown_all.sql) in Snowsight.

---

## Related

- **[tool-code-spend-controls](../tool-code-spend-controls/)** — Companion tool: control Cortex Code spend (CLI + Snowsight)
- **[Managing Cortex AI Function costs with Account Usage](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-func-cost-management)** — Source documentation
- **[CORTEX_AI_FUNCTIONS_USAGE_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_ai_functions_usage_history)** — Column reference
- **[Service Consumption Table](https://www.snowflake.com/legal-files/CreditConsumptionTable.pdf)** — Official Cortex AI pricing
