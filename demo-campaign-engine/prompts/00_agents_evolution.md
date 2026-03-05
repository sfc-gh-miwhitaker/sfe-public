# AGENTS.md Evolution

This document captures how `AGENTS.md` evolves across the workshop. Each version reflects the growing context the AI needs to maintain quality and consistency.

## v1 (Before Step 1) -- Environment + Naming Standards

Created before any AI interaction. The AI knows where things live and the naming conventions that keep all 7 steps compatible.

```markdown
# Casino Campaign Recommendation Engine

Campaign recommendation engine for casino operators.

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CAMPAIGN_ENGINE
- Warehouse: SFE_CAMPAIGN_ENGINE_WH

## Development Standards
- Naming: RAW_ prefix for staging tables (e.g. RAW_PLAYERS, RAW_PLAYER_ACTIVITY)
- IDs: INTEGER primary keys (Step 2 uses GENERATOR/UNIFORM for synthetic data)
- Objects: COMMENT = 'DEMO: <description> (Expires: 2026-05-01)' on all objects
- Constraints: PRIMARY KEY on every table, FOREIGN KEY where applicable
```

## v2 (After Step 3) -- Feature Engineering Standards

After Dynamic Tables and VECTOR construction. The AI now knows the feature pipeline patterns.

```markdown
# Casino Campaign Recommendation Engine

Campaign recommendation engine for casino operators with ML audience targeting and vector-based player lookalike matching.

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CAMPAIGN_ENGINE
- Warehouse: SFE_CAMPAIGN_ENGINE_WH

## Key Patterns
- Dynamic Tables with TARGET_LAG = '1 hour' for automated feature engineering
- VECTOR(FLOAT, 16) data type for player behavior embeddings
- Min-max normalization across all players for each feature
- COALESCE/NULLIF guards against division by zero

## Development Standards
- Naming: RAW_ prefix for staging tables; SFE_ prefix for account-level objects only
- IDs: INTEGER primary keys (GENERATOR/UNIFORM for synthetic data)
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT = 'DEMO: <description> (Expires: 2026-05-01)' on all objects
- Constraints: PRIMARY KEY on every table, FOREIGN KEY where applicable
- Deploy: One-command deployment via deploy_all.sql
```

## v3 (After Step 5) -- ML and Engine Patterns

After the recommendation engine. The AI knows ML, vector similarity, and LLM patterns.

```markdown
# Casino Campaign Recommendation Engine

Campaign recommendation engine for casino operators with ML audience targeting and vector-based player lookalike matching.

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CAMPAIGN_ENGINE
- Warehouse: SFE_CAMPAIGN_ENGINE_WH

## Key Patterns
- Dynamic Tables with TARGET_LAG = '1 hour' for automated feature engineering
- VECTOR(FLOAT, 16) data type for player behavior embeddings
- VECTOR_COSINE_SIMILARITY for lookalike player matching
- SNOWFLAKE.ML.CLASSIFICATION for campaign audience scoring
- SNOWFLAKE.CORTEX.COMPLETE for campaign recommendation generation
- Python stored procedures for vector aggregation logic (VECTOR not supported in SQL scripting)
- ML models trained on views using SYSTEM$REFERENCE

## Development Standards
- Naming: RAW_ prefix for staging tables; SFE_ prefix for account-level objects only
- IDs: INTEGER primary keys (GENERATOR/UNIFORM for synthetic data)
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT = 'DEMO: <description> (Expires: 2026-05-01)' on all objects
- Constraints: PRIMARY KEY on every table, FOREIGN KEY where applicable
- Deploy: One-command deployment via deploy_all.sql
```

## v4 (After Step 7) -- Full Project Context (Final)

After Streamlit and Cortex Agent. The AI has complete project knowledge.

Key additions in v4:
- Semantic view clause order: FACTS before DIMENSIONS (Snowflake syntax requirement)
- CREATE AGENT with YAML specification (not the older JSON-based CREATE CORTEX AGENT)
- Tool type `cortex_analyst_text_to_sql` with semantic view in `tool_resources`
- Streamlit deployed FROM Git repo stage with ADD LIVE VERSION FROM LAST

This is the version committed as the final `AGENTS.md` in the repository.

See the root `AGENTS.md` file for the full content of v4.
