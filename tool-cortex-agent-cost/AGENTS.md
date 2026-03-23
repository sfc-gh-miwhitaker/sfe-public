# Cortex REST API Cost -- AI-Pair Instructions

## Project Purpose

Track the dollar cost of Snowflake Cortex REST API calls. Data comes from
`SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY`; pricing rates come from
the Service Consumption Table Tables 6(b) and 6(c).

REST API calls are billed in **dollars per million tokens** -- a different billing
model from Cortex Agents, SQL AI functions, and Snowflake Intelligence (all credits).

## Project Structure

```
tool-cortex-agent-cost/
├── deploy_all.sql              # One-command deployment (Run All in Snowsight)
├── teardown_all.sql            # Complete cleanup
├── sql/
│   ├── 01_setup/               # Schema + warehouse
│   ├── 02_config/              # CORTEX_API_PRICING table ($/M-token rates)
│   ├── 03_views/               # 4 views: detail → costed → daily + model summaries
│   └── 04_streamlit/           # CREATE STREAMLIT + GRANT
└── streamlit/cortex_agent_cost/
    ├── streamlit_app.py        # Single-page dashboard (no multi-page)
    ├── environment.yml         # streamlit=1.35.0, plotly, snowpark
    └── utils/data.py           # Three query functions (totals, daily, model)
```

## Snowflake Environment

- **Database:** SNOWFLAKE_EXAMPLE
- **Schema:** CORTEX_AGENT_COST
- **Warehouse:** SFE_CORTEX_AGENT_COST_WH (XS, auto-suspend 60s)

## Key Concepts

- `CORTEX_REST_API_USAGE_HISTORY` has no CREDITS column -- only token counts
- `TOKENS_GRANULAR` is an OBJECT (not ARRAY): access via `:"input"::NUMBER`
- Dollar cost is calculated by joining with the `CORTEX_API_PRICING` table
- Pricing varies by model and inference region (regional vs global)
- `REGION_CATEGORY` in pricing table: 'DEFAULT' = regional rate fallback, 'GLOBAL' = lower rate for cross-region inference
- The costed view tries GLOBAL match first (when `INFERENCE_REGION ILIKE '%GLOBAL%'`), falls back to DEFAULT

## Development Standards

- All objects: `COMMENT = 'TOOL: ... (Expires: 2026-04-22)'`
- COMMENT placement: VIEW before AS, TABLE after columns, SCHEMA after name
- No SELECT * -- explicit columns only
- Sargable predicates only
