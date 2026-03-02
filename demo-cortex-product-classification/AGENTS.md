# Glaze & Classify

Product classification showdown: four progressively sophisticated approaches to classifying an international bakery catalog.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered)
- `streamlit/` -- Streamlit dashboard source
- `spcs/` -- Snowpark Container Services vision model
- `diagrams/` -- Architecture diagrams (Mermaid)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: GLAZE_AND_CLASSIFY
- Warehouse: SFE_GLAZE_AND_CLASSIFY_WH

## Key Patterns
- Four classification approaches: SQL keyword, simple Cortex, robust Cortex pipeline, SPCS vision
- AI_COMPLETE for LLM-based classification
- Snowpark Container Services for custom vision model
- Semantic view + Intelligence agent for analytics
- Multi-language product catalog (6 markets, 5+ languages)

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
- Naming: SFE_ prefix for account-level objects only; project objects scoped by schema

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql as the single entry point
- All new objects need COMMENT = 'DEMO: ... (Expires: 2026-05-01)'
- SPCS components are optional (require GPU compute pool)
- Classification accuracy comparison is the narrative arc
