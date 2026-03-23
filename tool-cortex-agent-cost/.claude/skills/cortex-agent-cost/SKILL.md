---
name: cortex-agent-cost
description: "Cortex REST API cost reporting tool. Tracks direct REST API token usage and calculates dollar cost from Service Consumption Table rates. Use when: API cost, REST API billing, token pricing, model cost."
---

# Cortex REST API Cost Tool

## Purpose

Single-page Streamlit dashboard showing Cortex REST API usage and dollar cost.
Data from `CORTEX_REST_API_USAGE_HISTORY`, pricing from Tables 6(b)/6(c).

## Architecture

```
CORTEX_REST_API_USAGE_HISTORY
        │
        v
  V_API_USAGE_DETAIL  ──── flatten TOKENS_GRANULAR
        │
        v
  V_API_USAGE_COSTED  ──── join CORTEX_API_PRICING table
        │
   ┌────┴────┐
   v         v
V_DAILY    V_MODEL     ──── aggregation views
   │         │
   v         v
  Streamlit Dashboard
```

## Key Files

| File | Role |
|------|------|
| `sql/02_config/01_pricing_table.sql` | $/M-token rates from Tables 6(b)/6(c) |
| `sql/03_views/02_usage_with_cost.sql` | Core cost calculation logic |
| `streamlit/cortex_agent_cost/streamlit_app.py` | Single-page dashboard |
| `streamlit/cortex_agent_cost/utils/data.py` | Query functions |

## Extension Playbook: Adding a New Model

1. Look up the model's rates in the current Service Consumption Table
2. INSERT into `CORTEX_API_PRICING` with `REGION_CATEGORY = 'DEFAULT'` (regional rate)
3. If global pricing exists, INSERT a second row with `REGION_CATEGORY = 'GLOBAL'`
4. Set `SOURCE_TABLE` to '6b' (prompt caching) or '6c' (no caching)
5. No view changes needed -- the join picks up new rows automatically

## Snowflake Objects

| Object | Type | Schema |
|--------|------|--------|
| `CORTEX_API_PRICING` | Table | `CORTEX_AGENT_COST` |
| `V_API_USAGE_DETAIL` | View | `CORTEX_AGENT_COST` |
| `V_API_USAGE_COSTED` | View | `CORTEX_AGENT_COST` |
| `V_DAILY_COST_SUMMARY` | View | `CORTEX_AGENT_COST` |
| `V_MODEL_COST_SUMMARY` | View | `CORTEX_AGENT_COST` |
| `CORTEX_AGENT_COST_APP` | Streamlit | `CORTEX_AGENT_COST` |

## Gotchas

- `TOKENS_GRANULAR` is an OBJECT (not ARRAY) -- use `:"input"` notation, not FLATTEN
- REST API billing is dollars/million-tokens, NOT credits -- completely different from Agent framework billing
- `INFERENCE_REGION` values are not yet fully documented; the costed view uses ILIKE pattern matching for GLOBAL detection and falls back to DEFAULT (regional) rates
- The `CORTEX_REST_API_USAGE_HISTORY` view has up to 365 days of data
- Pricing table must be manually updated when Snowflake publishes new rates
