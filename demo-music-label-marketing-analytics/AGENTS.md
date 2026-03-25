# Music Label Marketing Analytics

Marketing analytics platform for a music label (Apex Records) with AI-enriched campaign metadata, an editable spreadsheet interface, and natural-language queries over budget, spend, streams, and royalties.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered)
- `streamlit/` -- 5-page Streamlit dashboard
- `.claude/skills/` -- Project-specific AI skill

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: MUSIC_MARKETING
- Warehouse: SFE_MUSIC_MARKETING_WH

## Key Patterns
- Dynamic Tables with TARGET_LAG = '1 hour' for automated dimensional model refresh
- AI_CLASSIFY for auto-tagging campaign types from free-text descriptions
- AI_EXTRACT for pulling structured metadata (territory, genre, priority) from unstructured notes
- st.data_editor for spreadsheet-style budget entry that writes back to Snowflake
- Semantic View with FACTS-before-DIMENSIONS clause ordering
- CREATE AGENT with cortex_analyst_text_to_sql tool linked to semantic view
- Secure views for governed data sharing with distribution partners
- Budget alert task for hourly overspend monitoring

## Development Standards
- Naming: RAW_ prefix for raw tables; SFE_ prefix for account-level objects only
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
- Dynamic Tables use TARGET_LAG = '1 hour' for demo cadence
- AI_CLASSIFY categories: Single Launch, Album Cycle, Playlist Push, Tour Support, TikTok Promo
- AI_EXTRACT responseFormat uses simple object schema (not JSON schema)
- Semantic View lives in SEMANTIC_MODELS schema (not MUSIC_MARKETING)
- Streamlit uses FROM with Git repo stage, not ROOT_LOCATION

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
- [`guide-coco-setup`](../guide-coco-setup/) -- Cortex Code on-ramp
- [`demo-campaign-engine`](../demo-campaign-engine/) -- Casino campaign engine (similar ML/vector patterns)
- [`guide-agent-governance`](../guide-agent-governance/) -- Agent governance patterns
