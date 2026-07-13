---
name: media-campaign-analytics
description: "Art-of-the-possible demo: Cortex Agent chat over paid media KPIs. 5-min deploy, live demo, 'I want that' reaction. Triggers: campaign analytics, media demo, marketing AI, ROAS, CTR demo, Cortex Agent demo, ad performance NL, art of the possible, Snowflake Intelligence demo."
---

# Media Campaign Analytics — Project Skill

## Purpose

Deploy-and-demo in one meeting. The audience asks questions about ad campaigns in plain English and gets answers with charts. The goal is interest, not instruction — technical depth follows only after the reaction lands.

## Architecture

Structured analytics + unstructured document search in one agent, two tools:

```
Structured path:  Tables → V_CAMPAIGN_KPI → Semantic View → CampaignAnalytics tool
Document path:    DOC_CAMPAIGN_CONTENT → Cortex Search Service → CampaignDocs tool
Both paths:       → MEDIA_CAMPAIGN_AGENT → Snowflake Intelligence UI
```

The audience sees only the chat interface. The scaffolding:
- **Semantic View**: Maps business concepts (ROAS, CTR, budget pacing) to SQL. Accuracy lives here.
- **Cortex Search Service**: Indexes campaign documents for semantic search. The "qualitative brain."
- **Verified Queries**: Pre-tested Q&A pairs that seed the UI with starter prompts.
- **Agent Spec**: Routes quantitative vs qualitative vs hybrid questions to the right tool(s).

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | One-command deploy — paste into Snowsight Run All |
| `teardown_all.sql` | Full cleanup |
| `README.md` | Demo script + handling live moments |
| `ELI5.md` | Plain-language pitch framing |
| `sql/01_setup/01_create_schema.sql` | Schema + warehouse |
| `sql/02_data/01_create_tables.sql` | 4 tables (dim + fact) |
| `sql/02_data/02_load_sample_data.sql` | GENERATOR-based synthetic performance data |
| `sql/02_data/03_create_document_table.sql` | DOC_CAMPAIGN_CONTENT table |
| `sql/02_data/04_load_documents.sql` | 60 synthetic campaign documents |
| `sql/03_transformations/01_create_views.sql` | V_CAMPAIGN_KPI |
| `sql/04_cortex/01_create_semantic_view.sql` | SV_MEDIA_CAMPAIGN_ANALYTICS |
| `sql/04_cortex/01b_create_search_service.sql` | CAMPAIGN_DOCS_SEARCH (Cortex Search) |
| `sql/04_cortex/02_create_agent.sql` | MEDIA_CAMPAIGN_AGENT (both tools) |
| `sql/99_cleanup/teardown.sql` | Drop all project objects |

## Snowflake Objects

- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS`
- Warehouse: `SFE_MEDIA_CAMPAIGN_WH`
- Semantic View: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS`
- Search Service: `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.CAMPAIGN_DOCS_SEARCH`
- Agent: `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.MEDIA_CAMPAIGN_AGENT`

## Extension Playbook

- **Adapt for a different vertical**: Rename clients/channels, adjust metric ranges in the GENERATOR logic, update semantic view synonyms and sample values. The architecture stays identical.
- **Add a metric**: Add PRIVATE fact in semantic view, then a public metric expression. Update AI_SQL_GENERATION if the metric has edge cases.
- **Add a document**: INSERT into DOC_CAMPAIGN_CONTENT with appropriate DOC_TYPE, CLIENT_ID, and optional CAMPAIGN_ID. The search service picks it up on its next refresh cycle (within 1 minute).
- **Add a verified query**: Append to AI_VERIFIED_QUERIES. Set ONBOARDING_QUESTION TRUE for max 4 starter prompts in the agent UI.
- **Point at real data**: Replace `V_CAMPAIGN_KPI` with a view over actual tables. Update the semantic view's TABLE reference. Everything downstream (agent, UI) works unchanged.

## Gotchas

- **Cortex Search Service indexing**: The search service builds its index at creation time (INITIALIZE = ON_CREATE). Adds ~1-2 min to deploy. If it times out, the service still refreshes on schedule (TARGET_LAG '1 minute').
- **Connected TV**: Zero clicks/conversions by design. CTR/CVR/CPC return NULL for CTV. Demo this as intelligence ("the agent knows CTV is impression-only"), not a bug.
- **Synthetic data changes on each deploy**: GENERATOR uses RANDOM(). Don't screenshot expected values — they won't match next time.
- **Budget utilization > 100%**: Expected for some campaigns. Synthetic spend is randomized independently of budget.
- **Semantic view lives in a shared schema**: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS`, not the project schema. Teardown drops it explicitly.
- **`CREATE OR REPLACE SCHEMA`**: Intentional. Ensures clean state on redeploy. Don't change to `IF NOT EXISTS`.
