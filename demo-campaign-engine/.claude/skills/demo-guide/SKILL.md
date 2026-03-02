---
name: demo-guide
description: "Project-specific skill for the Casino Campaign Engine demo. Teaches AI tools about this project's patterns and conventions."
---

# Casino Campaign Engine -- Demo Guide

## When to Use
- Working with this project in any AI-pair tool
- Adding new features or extending the demo
- Debugging deployment issues

## Project Overview
Casino campaign recommendation engine with two core capabilities:
1. **Audience targeting** via SNOWFLAKE.ML.CLASSIFICATION
2. **Player lookalike matching** via VECTOR_COSINE_SIMILARITY on VECTOR(FLOAT,16)

## Key Patterns

### Naming
- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `CAMPAIGN_ENGINE`
- Warehouse: `SFE_CAMPAIGN_ENGINE_WH`
- All objects get COMMENT = 'DEMO: ... (Expires: 2026-05-01)'

### Data Flow
1. Raw tables (RAW_PLAYERS, RAW_PLAYER_ACTIVITY, RAW_CAMPAIGNS, RAW_CAMPAIGN_RESPONSES)
2. Dynamic Table DT_PLAYER_FEATURES aggregates 16 behavioral metrics
3. Dynamic Table DT_PLAYER_VECTORS normalizes features into VECTOR(FLOAT,16)
4. Engine layer: lookalike proc, ML classifier, LLM recommendations
5. Presentation: Streamlit dashboard + Cortex Intelligence Agent

### SQL Standards
- Explicit column lists (no SELECT *)
- QUALIFY for window function filtering
- Sargable predicates in WHERE clauses
- COMMENT metadata on every object

### Dynamic Tables
- TARGET_LAG = '1 hour' for demo cadence
- WAREHOUSE = SFE_CAMPAIGN_ENGINE_WH
- REFRESH_MODE = AUTO

### Vector Operations
- Feature vectors: VECTOR(FLOAT, 16)
- Similarity: VECTOR_COSINE_SIMILARITY(a, b)
- Construction: ARRAY_CONSTRUCT(...)::VECTOR(FLOAT, 16)

### Streamlit
- Uses FROM with Git repo stage (not legacy ROOT_LOCATION)
- QUERY_WAREHOUSE = SFE_CAMPAIGN_ENGINE_WH
- Session via `from snowflake.snowpark.context import get_active_session`
