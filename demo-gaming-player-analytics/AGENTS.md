# Gaming Player Analytics

Player behavior analytics platform for an indie gaming studio (Pixel Forge Studios) with AI-enriched player segmentation, churn risk scoring, and natural-language queries over engagement, revenue, and feedback data.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered)
- `streamlit/` -- 4-page Streamlit dashboard
- `.claude/skills/` -- Project-specific AI skill

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: GAMING_PLAYER_ANALYTICS
- Warehouse: SFE_GAMING_PLAYER_ANALYTICS_WH

## Key Patterns
- Dynamic Tables with varied TARGET_LAG to demonstrate optimization (1 hour for profiles, DOWNSTREAM for engagement)
- AI_CLASSIFY for player cohort segmentation (whale, casual, churning, new) inside Dynamic Tables
- AI_CLASSIFY for sentiment analysis on player feedback (Positive, Negative, Neutral) inside Dynamic Tables
- AI_EXTRACT for structured metadata extraction from free-text feedback
- Semantic View with FACTS-before-DIMENSIONS clause ordering
- CREATE AGENT with cortex_analyst_text_to_sql tool linked to semantic view
- COPY-based ingestion pattern mirroring real production pipelines

## Development Standards
- Naming: RAW_ prefix for raw tables; DT_ for dynamic tables; SFE_ prefix for account-level objects only
- IDs: INTEGER primary keys with GENERATOR/UNIFORM for synthetic data
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT = 'DEMO: <description> (Expires: 2026-04-24)' on all objects
- Constraints: PRIMARY KEY on every table, FOREIGN KEY where applicable
- Deploy: One-command deployment via deploy_all.sql

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql as the single entry point
- All new objects need COMMENT = 'DEMO: ... (Expires: 2026-04-24)'
- Dynamic Tables use TARGET_LAG = '1 hour' for most tables, DOWNSTREAM where noted
- AI_CLASSIFY categories for cohorts: Whale, Casual, Churning, New
- AI_CLASSIFY categories for sentiment: Positive, Negative, Neutral
- AI_EXTRACT responseFormat uses simple object schema (not JSON schema)
- Semantic View lives in SEMANTIC_MODELS schema (not GAMING_PLAYER_ANALYTICS)
- Streamlit uses FROM with Git repo stage, not ROOT_LOCATION
- SNOWFLAKE.CORTEX.SENTIMENT does NOT work in Dynamic Tables; use AI_CLASSIFY with sentiment categories instead

## Helping New Users

If the user seems confused, asks basic questions like "what is this" or "how do I start", or appears unfamiliar with the tools:

1. **Greet them warmly** and explain what this project does in one plain-English sentence
2. **Check deployment status** -- ask if they've run `deploy_all.sql` in Snowsight yet
3. **Guide step-by-step** -- if not deployed, walk them through:
   - Opening Snowsight (the Snowflake web interface)
   - Creating a new SQL worksheet
   - Pasting the contents of `deploy_all.sql`
   - Clicking "Run All" (the play button with two arrows)
4. **Suggest what to try** -- after deployment, give 2-3 specific things they can do

**Assume no technical background.** Define terms when you use them. "Snowsight is the Snowflake web interface where you run SQL" is better than just "run this in Snowsight."

## Related Projects
- [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) -- Install and connect
- [`demo-campaign-engine`](../demo-campaign-engine/) -- Casino campaign engine (ML + vector patterns)
- [`demo-music-label-marketing-analytics`](../demo-music-label-marketing-analytics/) -- Music label marketing (AI enrichment + spreadsheet patterns)
- [`guide-agent-governance`](../guide-agent-governance/) -- Agent governance patterns
