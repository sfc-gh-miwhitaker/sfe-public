---
name: demo-campaign-engine
description: "Casino campaign recommendation engine with ML targeting and vector lookalike matching. Triggers: campaign engine, casino campaigns, player targeting, ML CLASSIFICATION, vector similarity, VECTOR_COSINE_SIMILARITY, player lookalike, dynamic table features, campaign recommendations."
---

# Casino Campaign Engine -- Demo Guide

## Purpose

Campaign recommendation engine for casino operators with ML audience targeting via SNOWFLAKE.ML.CLASSIFICATION and player lookalike matching via VECTOR_COSINE_SIMILARITY on VECTOR(FLOAT,16).

## When to Use

- Working with this project in any AI-pair tool
- Adding new features or extending the demo
- Debugging deployment issues
- Understanding the ML/vector pipeline

## Architecture

```
RAW_PLAYERS, RAW_PLAYER_ACTIVITY, RAW_CAMPAIGNS, RAW_CAMPAIGN_RESPONSES
       │
       ▼
DT_PLAYER_FEATURES (Dynamic Table: 16 behavioral metrics)
       │
       ▼
DT_PLAYER_VECTORS (Dynamic Table: VECTOR(FLOAT,16) normalized)
       │
       ├── ML.CLASSIFICATION (audience targeting)
       ├── VECTOR_COSINE_SIMILARITY (player lookalike)
       └── CORTEX.COMPLETE (LLM recommendations)
              │
              ▼
       Streamlit Dashboard + Cortex Intelligence Agent
```

## Key Files

| File | Purpose |
|------|---------|
| `sql/02_data/` | Raw tables and sample data |
| `sql/03_features/` | DT_PLAYER_FEATURES, DT_PLAYER_VECTORS |
| `sql/04_engine/` | ML classifier, lookalike proc, LLM recommendations |
| `sql/05_cortex/` | Semantic views (FACTS before DIMENSIONS), Intelligence Agent |
| `streamlit/` | Dashboard app |

## Key Patterns

- Dynamic Tables: `TARGET_LAG = '1 hour'`, `REFRESH_MODE = AUTO`
- Vector construction: `ARRAY_CONSTRUCT(...)::VECTOR(FLOAT, 16)`
- Similarity: `VECTOR_COSINE_SIMILARITY(a, b)`
- Semantic views: FACTS-before-DIMENSIONS ordering
- Agent: `CREATE AGENT` with YAML spec, `orchestration: auto`

## Extension Playbook: Adding a New Feature to Player Vectors

1. Add the metric computation to `DT_PLAYER_FEATURES` in `sql/03_features/`
2. Include the new metric in the `ARRAY_CONSTRUCT(...)::VECTOR(FLOAT, N)` in `DT_PLAYER_VECTORS`
3. Update the vector dimension (`N`) in the VECTOR type declaration
4. Update lookalike proc if similarity thresholds need adjustment
5. Rebuild downstream Dynamic Tables

## Extension Playbook: Adding a New Campaign Type

1. Add campaign rows to `RAW_CAMPAIGNS` sample data
2. Update the ML classifier training data if the campaign type has distinct response patterns
3. Add the campaign type to the Streamlit dashboard filters
4. Update the LLM recommendation prompt to include the new type

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE` |
| Warehouse | `SFE_CAMPAIGN_ENGINE_WH` |
| Dynamic Tables | `DT_PLAYER_FEATURES`, `DT_PLAYER_VECTORS` |
| Semantic View | In `SEMANTIC_MODELS` schema |
| Agent | Intelligence Agent with cortex_analyst tool |
| Streamlit | Git-integrated dashboard |

## Gotchas

- Vector dimension must match across all operations (currently 16)
- FACTS-before-DIMENSIONS ordering in semantic view YAML is required
- ML.CLASSIFICATION requires sufficient training data per class
- Streamlit uses `FROM` with Git repo stage (not legacy ROOT_LOCATION)
- `QUERY_WAREHOUSE` must be set on the Streamlit object
