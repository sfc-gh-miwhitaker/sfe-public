# Cortex REST API Cost -- AI-Pair Instructions

## Project Purpose

Track dollar cost of Snowflake Cortex REST API calls using
`SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY` and pricing rates
from the Service Consumption Table (Tables 6b/6c).

## Project Structure

```
tool-cortex-agent-cost/
├── deploy_all.sql              # One-command deployment
├── teardown_all.sql            # Complete cleanup
├── sql/
│   ├── 01_setup/               # Schema + warehouse
│   ├── 02_config/              # CORTEX_API_PRICING table ($/M-token rates)
│   ├── 03_views/               # 4 views (detail → costed → summaries)
│   └── 04_streamlit/           # CREATE STREAMLIT
└── streamlit/cortex_agent_cost/
    ├── streamlit_app.py        # Single-page dashboard
    ├── environment.yml
    └── utils/data.py           # Query functions
```

## Snowflake Environment

- **Database:** SNOWFLAKE_EXAMPLE
- **Schema:** CORTEX_AGENT_COST
- **Warehouse:** SFE_CORTEX_AGENT_COST_WH

## Key Concepts

- REST API billing is in **dollars per million tokens**, not credits
- `TOKENS_GRANULAR` is an OBJECT: access via `:"input"::NUMBER`, `:"output"::NUMBER`
- Pricing varies by model and inference region (regional vs global)
- `CORTEX_API_PRICING` table has `REGION_CATEGORY`: 'DEFAULT' (regional rate), 'GLOBAL'
- The costed view joins on GLOBAL when `INFERENCE_REGION` contains 'GLOBAL' or 'CROSS', otherwise falls back to DEFAULT

## Standards

- All new objects: `COMMENT = 'TOOL: ... (Expires: 2026-04-22)'`
- COMMENT placement: VIEW before AS, TABLE after columns, SCHEMA after name
- No SELECT * in views -- explicit columns only
