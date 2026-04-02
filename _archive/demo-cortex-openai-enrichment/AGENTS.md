# AI-First Data Engineering: OpenAI + Snowflake Cortex

Transform complex OpenAI API responses using Snowflake's native Cortex AI functions for classification, sentiment analysis, and summarization.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered)
- `streamlit/` -- Streamlit dashboard source
- `diagrams/` -- Architecture diagrams (Mermaid)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: OPENAI_DATA_ENG
- Warehouse: SFE_OPENAI_DATA_ENG_WH

## Key Patterns
- Three approaches: Schema-on-Read (FLATTEN + Views), Medallion (Dynamic Tables), Cortex AI Enrichment
- External Access Integration for OpenAI API calls
- AI_COMPLETE, AI_CLASSIFY, AI_SENTIMENT for Cortex enrichment
- Dynamic Tables with TARGET_LAG for medallion silver/gold layers
- VARIANT column for raw JSON storage, FLATTEN for extraction

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
- Cortex AI functions are the headline feature; external OpenAI calls are for comparison
- Streamlit app is embedded in deploy_all.sql (not a separate file deployment)

## Related Projects
- [`demo-api-quickbooks-medallion`](../demo-api-quickbooks-medallion/) -- Another external access + Cortex AI demo with medallion architecture
- [`tool-api-data-fetcher`](../tool-api-data-fetcher/) -- Generic external access pattern
- [`guide-cortex-anthropic-redirect`](../guide-cortex-anthropic-redirect/) -- Redirect Anthropic SDK calls through Cortex
