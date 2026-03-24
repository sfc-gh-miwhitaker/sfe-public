# Casino Campaign Recommendation Engine

Campaign recommendation engine for casino operators with ML audience targeting and vector-based player lookalike matching.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered)
- `streamlit/` -- Streamlit dashboard source

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CAMPAIGN_ENGINE
- Warehouse: SFE_CAMPAIGN_ENGINE_WH

## Key Patterns
- Dynamic Tables with TARGET_LAG for automated feature engineering refresh
- VECTOR(FLOAT, 16) data type for player behavior embeddings
- VECTOR_COSINE_SIMILARITY for lookalike player matching
- SNOWFLAKE.ML.CLASSIFICATION for campaign audience scoring
- SNOWFLAKE.CORTEX.COMPLETE for campaign recommendation generation
- Semantic views: FACTS before DIMENSIONS (clause order matters)
- CREATE AGENT with YAML spec; tool type `cortex_analyst_text_to_sql`; semantic view in `tool_resources`
- Python stored procedures for vector aggregation logic

## Development Standards
- Naming: RAW_ prefix for staging tables; SFE_ prefix for account-level objects only
- IDs: INTEGER primary keys (GENERATOR/UNIFORM for synthetic data)
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT = 'DEMO: <description> (Expires: 2026-05-01)' on all objects
- Constraints: PRIMARY KEY on every table, FOREIGN KEY where applicable
- Deploy: One-command deployment via deploy_all.sql

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql as the single entry point
- All new objects need COMMENT = 'DEMO: ... (Expires: 2026-05-01)'
- Dynamic Tables use TARGET_LAG = '1 hour' for demo cadence
- VECTOR columns are VECTOR(FLOAT, 16) -- 16 behavioral features
- ML models are created with SNOWFLAKE.ML.CLASSIFICATION
- Streamlit uses FROM with Git repo stage, not ROOT_LOCATION

## Related Projects
- [`guide-coco-setup`](../guide-coco-setup/) -- Cortex Code on-ramp (prerequisite for GUIDED_BUILD workshop)
- [`guide-agent-skills`](../guide-agent-skills/) -- Skills architecture and context budget management
- [`guide-coco-governance-general`](../guide-coco-governance-general/) -- AI coding tool governance workshop
- [`demo-cortex-teams-agent`](../demo-cortex-teams-agent/) -- Deploy a Cortex Agent to Microsoft Teams
