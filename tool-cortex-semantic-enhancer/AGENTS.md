# Semantic View Enhancer

Enhance Snowflake semantic views with AI-improved descriptions using Cortex AI.

## Project Structure
- `deploy.sql` -- Single entry point (Run All in Snowsight)
- `teardown.sql` -- Complete cleanup
- `diagrams/` -- Architecture diagrams

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: SEMANTIC_ENHANCEMENTS
- Warehouse: SFE_ENHANCEMENT_WH

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy.sql
- AI: Use `AI_COMPLETE` (not deprecated `SNOWFLAKE.CORTEX.COMPLETE`)

## When Helping with This Project
- Default model is `snowflake-llama-3.3-70b` (cost-optimized)
- `AI_COMPLETE` is the current function name (replaces COMPLETE)
- Original semantic views are never modified; enhanced copies are created
- Python runtime: use 3.11 (GA) unless 3.12 preview features are needed
- All new objects need COMMENT = 'DEMO: ... (Expires: YYYY-MM-DD)'
