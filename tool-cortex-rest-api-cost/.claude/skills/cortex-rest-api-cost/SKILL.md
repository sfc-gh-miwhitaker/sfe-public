---
name: cortex-rest-api-cost
description: "Cortex REST API cost reporting tool. Tracks direct REST API token usage and calculates dollar cost from Service Consumption Table rates (Tables 6b/6c). Use when: API cost, REST API billing, token pricing, model cost, consumption table."
---

# Cortex REST API Cost Tool

## Purpose

Single-page Streamlit dashboard showing Cortex REST API usage and dollar cost.
Data from `CORTEX_REST_API_USAGE_HISTORY`, pricing from Service Consumption Table
Tables 6(b) (prompt caching models) and 6(c) (non-caching models).

## Architecture

```
CORTEX_REST_API_USAGE_HISTORY
        │
        v
  V_API_USAGE_DETAIL  ──── flatten TOKENS_GRANULAR OBJECT → input/output columns
        │
        v
  V_API_USAGE_COSTED  ──── join CORTEX_API_PRICING, compute $/request
        │
   ┌────┴────┐
   v         v
V_DAILY    V_MODEL     ──── aggregation views
   │         │
   v         v
  Streamlit Dashboard   ──── KPIs, daily bar chart, model table
```

## Key Files

| File | Role |
|------|------|
| `sql/02_config/01_pricing_table.sql` | 40 rows of $/M-token rates from Tables 6(b)/6(c) |
| `sql/03_views/02_usage_with_cost.sql` | Core cost calculation: two LEFT JOINs (GLOBAL, DEFAULT) with COALESCE |
| `streamlit/cortex_rest_api_cost/streamlit_app.py` | Single-page dashboard with plotly bar chart |
| `streamlit/cortex_rest_api_cost/utils/data.py` | Three query functions: `get_totals`, `get_daily_summary`, `get_model_summary` |

## Extension Playbook: Adding a New Model

1. Look up the model's $/million-token rates in the current [Service Consumption Table](https://www.snowflake.com/legal-files/CreditConsumptionTable.pdf)
2. `INSERT INTO CORTEX_API_PRICING` with `REGION_CATEGORY = 'DEFAULT'` (use regional rate)
3. If the model has separate global pricing, INSERT a second row with `REGION_CATEGORY = 'GLOBAL'`
4. Set `SOURCE_TABLE` to `'6b'` (prompt caching) or `'6c'` (no caching)
5. No view or Streamlit changes needed -- the join picks up new pricing rows automatically

## Extension Playbook: Adding Another Usage View

To cover Cortex Agents, SQL AI Functions, or Intelligence alongside REST API:

1. Create a new detail view in `sql/03_views/` reading from the target `ACCOUNT_USAGE` view
2. Those views bill in **credits** not dollars -- use `TOKEN_CREDITS` or `CREDITS` columns directly
3. To convert credits → dollars, you need the customer's contracted credit rate (not in `ACCOUNT_USAGE`)
4. Add a new query function in `utils/data.py` and a new section in `streamlit_app.py`

## Snowflake Objects

| Object | Type | Schema |
|--------|------|--------|
| `CORTEX_API_PRICING` | Table | `CORTEX_REST_API_COST` |
| `V_API_USAGE_DETAIL` | View | `CORTEX_REST_API_COST` |
| `V_API_USAGE_COSTED` | View | `CORTEX_REST_API_COST` |
| `V_DAILY_COST_SUMMARY` | View | `CORTEX_REST_API_COST` |
| `V_MODEL_COST_SUMMARY` | View | `CORTEX_REST_API_COST` |
| `CORTEX_REST_API_COST_APP` | Streamlit | `CORTEX_REST_API_COST` |

## Gotchas

- REST API billing is **dollars/million-tokens**, NOT credits -- completely different billing model from Cortex Agents and SQL AI functions
- `TOKENS_GRANULAR` is an OBJECT (not ARRAY) -- use `:"input"` semi-structured notation, not LATERAL FLATTEN
- `INFERENCE_REGION` exact values are not fully documented; the costed view uses ILIKE pattern matching (`%GLOBAL%`, `%CROSS%`) and falls back to DEFAULT (regional) rates when no match
- `CORTEX_REST_API_USAGE_HISTORY` retains up to 365 days of data but has ~45 min latency
- The pricing table is static -- it must be updated manually when Snowflake publishes new rates in the Service Consumption Table
- `CREATE OR REPLACE TABLE` in the pricing script means re-deploying wipes any manual rate updates -- use `INSERT`/`UPDATE` for ad-hoc changes
