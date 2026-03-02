# AGENTS.md Evolution

This document captures how `AGENTS.md` evolved across the four acts of the AI-pair programming demo. Each version reflects the growing context the AI needed to maintain quality and consistency.

## v1 (Act 1) -- Minimal Context

After scaffolding. The AI only knows the project name and Snowflake environment.

```markdown
# Casino Campaign Recommendation Engine

Campaign recommendation engine for casino operators.

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CAMPAIGN_ENGINE
- Warehouse: SFE_CAMPAIGN_ENGINE_WH
```

## v2 (Act 2) -- Feature Engineering Standards

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
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
```

## v3 (Act 3) -- ML and Engine Patterns

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
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
- Naming: SFE_ prefix for account-level objects only; project objects scoped by schema
```

## v4 (Act 4) -- Full Project Context (Final)

After Streamlit and Cortex Agent. The AI has complete project knowledge.

This is the version committed as the final `AGENTS.md` in the repository.

See the root `AGENTS.md` file for the full content of v4.
