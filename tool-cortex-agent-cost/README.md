# Cortex REST API Cost

![Expires](https://img.shields.io/badge/Expires-2026--04--22-orange)
**TOOL PROJECT** | Pair-programmed by SE Community + Cortex Code

Track and visualize the dollar cost of Snowflake Cortex REST API calls.

## What This Does

Queries `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY` for direct REST API
model calls, applies pricing rates from the Service Consumption Table (Tables 6b/6c),
and displays usage and cost in a single-page Streamlit dashboard.

REST API calls are billed in **dollars per million tokens** (not credits). This tool
calculates the dollar cost from token counts and model-specific rates.

## Quick Start

1. Copy `deploy_all.sql` into Snowsight
2. Click **Run All**
3. Open **Projects > Streamlit > CORTEX_AGENT_COST_APP**

## What Gets Deployed

| Object | Type | Purpose |
|--------|------|---------|
| `SNOWFLAKE_EXAMPLE.CORTEX_AGENT_COST` | Schema | All tool objects |
| `SFE_CORTEX_AGENT_COST_WH` | Warehouse | XS, auto-suspend 60s |
| `CORTEX_API_PRICING` | Table | $/M-token rates from Tables 6(b)/6(c) |
| `V_API_USAGE_DETAIL` | View | Flattened token breakdown per request |
| `V_API_USAGE_COSTED` | View | Dollar cost per request |
| `V_DAILY_COST_SUMMARY` | View | Daily aggregation |
| `V_MODEL_COST_SUMMARY` | View | Per-model aggregation |
| `CORTEX_AGENT_COST_APP` | Streamlit | Single-page cost dashboard |

## Teardown

Copy `teardown_all.sql` into Snowsight and click **Run All**.

## Updating Pricing

When Snowflake updates the Service Consumption Table, update the rows in
`CORTEX_API_PRICING`. The table is keyed on `(MODEL_NAME, REGION_CATEGORY)`.

## Data Source

`SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY` -- tracks direct REST API
calls to Cortex models. Columns: `START_TIME`, `END_TIME`, `REQUEST_ID`, `MODEL_NAME`,
`TOKENS`, `TOKENS_GRANULAR`, `USER_ID`, `INFERENCE_REGION`.

This view does **not** include:
- Cortex Agent framework calls (see `CORTEX_AGENT_USAGE_HISTORY`)
- SQL-invoked AI functions (see `CORTEX_AI_FUNCTIONS_USAGE_HISTORY`)
- Snowflake Intelligence usage (see `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY`)
