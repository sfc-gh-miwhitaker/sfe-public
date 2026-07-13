---
name: media-campaign-analytics
description: "Art-of-the-possible demo: Cortex Agent chat over paid media KPIs. 5-min deploy, live demo, 'I want that' reaction. Triggers: campaign analytics, media demo, marketing AI, ROAS, CTR demo, Cortex Agent demo, ad performance NL, art of the possible, Snowflake Intelligence demo."
---

# Media Campaign Analytics — Project Skill

## Purpose

Deploy-and-demo in one meeting. The audience asks questions about ad campaigns in plain English and gets answers with charts. The goal is interest, not instruction — technical depth follows only after the reaction lands.

## Architecture

Four-table star schema → flattened KPI view → Semantic View → Cortex Agent → Snowflake Intelligence UI.

The audience sees only the chat interface. The scaffolding (tables, view, semantic view) exists to make the answers correct and fast. When explaining to a technical audience *after* interest is established:

- **Semantic View**: The "dictionary" that maps business concepts (ROAS, CTR, budget pacing) to SQL. This is where accuracy lives.
- **Verified Queries**: Pre-tested Q&A pairs that seed the UI with starter prompts and improve answer quality for common questions.
- **Agent Spec**: Thin wrapper — points at the semantic view, adds response formatting rules and a chart tool.

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | One-command deploy — paste into Snowsight Run All |
| `teardown_all.sql` | Full cleanup |
| `README.md` | Demo script + handling live moments |
| `ELI5.md` | Plain-language pitch framing |
| `sql/01_setup/01_create_schema.sql` | Schema + warehouse |
| `sql/02_data/01_create_tables.sql` | 4 tables (dim + fact) |
| `sql/02_data/02_load_sample_data.sql` | GENERATOR-based synthetic data |
| `sql/03_transformations/01_create_views.sql` | V_CAMPAIGN_KPI |
| `sql/04_cortex/01_create_semantic_view.sql` | SV_MEDIA_CAMPAIGN_ANALYTICS |
| `sql/04_cortex/02_create_agent.sql` | MEDIA_CAMPAIGN_AGENT |
| `sql/99_cleanup/teardown.sql` | Drop all project objects |

## Snowflake Objects

- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS`
- Warehouse: `SFE_MEDIA_CAMPAIGN_WH`
- Semantic View: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS`
- Agent: `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.MEDIA_CAMPAIGN_AGENT`

## Extension Playbook

- **Adapt for a different vertical**: Rename clients/channels, adjust metric ranges in the GENERATOR logic, update semantic view synonyms and sample values. The architecture stays identical.
- **Add a metric**: Add PRIVATE fact in semantic view, then a public metric expression. Update AI_SQL_GENERATION if the metric has edge cases.
- **Add a verified query**: Append to AI_VERIFIED_QUERIES. Set ONBOARDING_QUESTION TRUE for max 4 starter prompts in the agent UI.
- **Point at real data**: Replace `V_CAMPAIGN_KPI` with a view over actual tables. Update the semantic view's TABLE reference. Everything downstream (agent, UI) works unchanged.

## Gotchas

- **Connected TV**: Zero clicks/conversions by design. CTR/CVR/CPC return NULL for CTV. Demo this as intelligence ("the agent knows CTV is impression-only"), not a bug.
- **Synthetic data changes on each deploy**: GENERATOR uses RANDOM(). Don't screenshot expected values — they won't match next time.
- **Budget utilization > 100%**: Expected for some campaigns. Synthetic spend is randomized independently of budget.
- **Semantic view lives in a shared schema**: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS`, not the project schema. Teardown drops it explicitly.
- **`CREATE OR REPLACE SCHEMA`**: Intentional. Ensures clean state on redeploy. Don't change to `IF NOT EXISTS`.
