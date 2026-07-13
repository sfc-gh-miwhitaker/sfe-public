---
name: media-campaign-analytics
description: "Media campaign performance analytics demo. Cortex Agent + Snowflake Intelligence over synthetic marketing KPI data. Triggers: campaign analytics, media demo, marketing AI, ROAS, CTR demo, Cortex Analyst demo, ad performance NL."
---

# Media Campaign Analytics — Project Skill

## Purpose

Cortex Agent demo showing natural language exploration of paid media campaign performance data. Built for media agencies and marketing analytics personas. No Streamlit — the UI is Snowflake Intelligence (AI & ML > Agents).

## Architecture

Four-table star schema → flattened KPI view → Semantic View → Cortex Agent → Snowflake Intelligence UI.

- **Dim tables**: CLIENT (verticals/tiers), CHANNEL (5 media types), CAMPAIGN (budget/dates/objective)
- **Fact table**: FACT_DAILY_PERFORMANCE — one row per campaign per day with impressions, clicks, conversions, spend, revenue
- **View**: V_CAMPAIGN_KPI joins all four tables into a single wide row for the semantic layer
- **Semantic View**: Defines 14 dimensions, 6 private facts, 8 public metrics (ROAS, CTR, CPM, CPC, CVR, budget utilization), plus AI_SQL_GENERATION guidance and 8 verified queries
- **Agent**: MEDIA_CAMPAIGN_AGENT with cortex_analyst_text_to_sql + data_to_chart tools

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | One-command deploy — paste into Snowsight Run All |
| `teardown_all.sql` | Full cleanup |
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

- **Add a client**: Insert into DIM_CLIENT, create campaigns in DIM_CAMPAIGN. Fact rows auto-populate on next deploy.
- **Add a channel**: Insert into DIM_CHANNEL, update GENERATOR logic in load_sample_data, add channel-specific metric ranges in fact generation.
- **Add a metric**: Add PRIVATE fact in semantic view, then a public metric expression. Update AI_SQL_GENERATION if the metric has edge cases.
- **Add a verified query**: Append to AI_VERIFIED_QUERIES in the semantic view. Set ONBOARDING_QUESTION TRUE for max 4 sample questions shown in the agent UI.

## Gotchas

- **Connected TV**: Zero clicks/conversions by design. All CTR/CVR/CPC metrics return NULL for CTV. Verified queries exclude CTV where appropriate using `channel_name != 'Connected TV'`.
- **Budget utilization > 100%**: Expected for some campaigns — synthetic spend is randomized independently of budget.
- **Semantic view schema**: Lives in `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS` (shared schema), not the project schema. Teardown drops it explicitly.
- **GENERATOR randomness**: Data changes on each deploy. Don't hardcode expected row counts or metric values in tests.
- **deploy_all.sql uses `CREATE OR REPLACE SCHEMA`**: This is intentional — ensures a clean state. Don't change to `IF NOT EXISTS`.
