---
name: media-campaign-analytics
description: "Media campaign performance analytics demo. Cortex Agent + Snowflake Intelligence over synthetic marketing KPI data. Triggers: campaign analytics, media demo, marketing AI, ROAS, CTR demo, Cortex Analyst demo, ad performance NL."
---

# Media Campaign Analytics — Project Skill

## Purpose

Cortex Agent demo showing natural language exploration of paid media campaign performance data. Built for media agencies and marketing analytics personas. No Streamlit — the UI is Snowflake Intelligence (AI & ML > Agents).

## Architecture

<!-- Completed at checkpoint 9 -->

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

<!-- Completed at checkpoint 9 -->

## Gotchas

<!-- Completed at checkpoint 9 -->
