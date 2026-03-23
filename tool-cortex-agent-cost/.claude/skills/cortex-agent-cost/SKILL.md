---
name: cortex-agent-cost
description: "Project-specific skill for Cortex Agent Cost tool. Granular cost reporting and forecasting for Cortex Agent and Snowflake Intelligence via ACCOUNT_USAGE views with TOKENS_GRANULAR/CREDITS_GRANULAR flattening. Use when working on agent cost analysis, token breakdowns, or credit forecasting."
---

# Cortex Agent Cost

## Purpose
Streamlit in Snowflake dashboard for deep cost visibility into Cortex Agent and Snowflake Intelligence usage, flattening per-model token and credit breakdowns that the broader Cortex Cost Intelligence tool does not expose.

## Architecture
```
ACCOUNT_USAGE (2 views)
  ├── CORTEX_AGENT_USAGE_HISTORY
  └── SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
        │
  ┌─────┴─────┐
  │ Detail     │  V_AGENT_DETAIL, V_INTELLIGENCE_DETAIL
  │ Views      │  (90-day window, explicit columns)
  └─────┬─────┘
        │
  ┌─────┴─────┐
  │ Combined   │  V_AGENT_COMBINED (UNION ALL + service_type)
  └─────┬─────┘
        │
  ┌─────┴──────────┐
  │ Granular Views  │  V_TOKEN_GRANULAR, V_CREDIT_GRANULAR
  │ (LATERAL        │  (triple FLATTEN on arrays)
  │  FLATTEN)       │
  └─────┬──────────┘
        │
  ┌─────┴─────┐
  │ Summary   │  V_DAILY_SUMMARY, V_AGENT_COST_SUMMARY,
  │ Views     │  V_MODEL_COST_SUMMARY, V_USER_AGENT_SPEND,
  │           │  V_CACHE_EFFICIENCY, V_FORECAST_BASE
  └─────┬─────┘
        │
  ┌─────┴─────┐
  │ Streamlit │  5-page dashboard (FROM Git stage)
  └───────────┘
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Tier 1 Git FROM entry point for Snowsight |
| `teardown_all.sql` | Complete cleanup |
| `sql/01_setup/01_schema_and_warehouse.sql` | Schema and warehouse creation |
| `sql/02_config/01_config_table.sql` | Config table with MERGE defaults |
| `sql/03_views/*.sql` | 11 monitoring views (detail → granular → summary) |
| `sql/04_streamlit/01_create_streamlit.sql` | CREATE STREAMLIT + activate |
| `streamlit/cortex_agent_cost/` | Multi-page Streamlit app |

## Adding a New Summary View

1. Create `sql/03_views/12_new_view.sql` following the naming pattern
2. Add `COMMENT = 'TOOL: ... (Expires: 2026-04-22)'` before the `AS` keyword
3. Reference upstream views (V_AGENT_COMBINED or V_TOKEN_GRANULAR) — never query ACCOUNT_USAGE directly from summary views
4. Add the EXECUTE IMMEDIATE FROM line to `deploy_all.sql` after the last existing view
5. Add a query function in `streamlit/cortex_agent_cost/utils/data.py`
6. Use the data in a Streamlit page

## Snowflake Objects
- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `CORTEX_AGENT_COST`
- Warehouse: `SFE_CORTEX_AGENT_COST_WH`
- Streamlit: `CORTEX_AGENT_COST_APP`
- Config table: `AGENT_COST_CONFIG`
- All objects have `COMMENT = 'TOOL: ... (Expires: 2026-04-22)'`

## Gotchas
- `TOKENS_GRANULAR` array elements contain a `start_time` key that is NOT a service type — always filter with `svc.key != 'start_time'` when flattening
- View creation order matters: detail views must exist before combined, combined before granular, granular before summaries
- `CORTEX_AGENT_USAGE_HISTORY` does NOT include Snowflake Intelligence traffic (and vice versa) — that's why V_AGENT_COMBINED unions both
- ACCOUNT_USAGE views lag up to 45 minutes; the Streamlit app warns users about this
- `CREATE STREAMLIT ... FROM @git_stage` copies files once; use `ALTER STREAMLIT ADD LIVE VERSION FROM LAST` to activate
