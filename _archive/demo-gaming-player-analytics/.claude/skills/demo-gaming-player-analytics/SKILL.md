---
name: demo-gaming-player-analytics
description: "Player behavior analytics for an indie gaming studio. Dynamic Tables, AI_CLASSIFY for cohort segmentation and sentiment, AI_EXTRACT for feedback metadata, Semantic Views, Intelligence Agents, Streamlit dashboards. Use when working with gaming analytics, player segmentation, churn risk, or engagement pipelines."
---

# Gaming Player Analytics

## Purpose
Demonstrates how to layer AI enrichment and self-service analytics on top of an existing Dynamic Table data engineering pipeline for a gaming studio's player telemetry data.

## Architecture
RAW tables (players, events, purchases, feedback) flow through DT transformations: DT_PLAYER_PROFILES adds AI_CLASSIFY cohort labels, DT_SESSION_METRICS aggregates engagement, DT_FEEDBACK_ENRICHED runs AI_EXTRACT + AI_CLASSIFY sentiment. Fact tables (FACT_PLAYER_LIFETIME, FACT_DAILY_ENGAGEMENT) and dimensions (DIM_PLAYERS, DIM_DATES) feed a semantic view powering both a Streamlit dashboard and an Intelligence Agent.

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Single entry point for Snowsight deployment |
| `sql/01_setup/01_create_schema.sql` | Schema and warehouse creation |
| `sql/02_data/01_create_tables.sql` | Raw table definitions |
| `sql/02_data/02_load_sample_data.sql` | Synthetic player data generation |
| `sql/03_transformations/01_dynamic_tables_profiles.sql` | Player profiles with AI cohort assignment |
| `sql/03_transformations/02_dynamic_tables_engagement.sql` | Session metrics and engagement features |
| `sql/03_transformations/03_ai_enrichment.sql` | Feedback enrichment with AI_EXTRACT + AI_CLASSIFY sentiment |
| `sql/03_transformations/04_dynamic_tables_facts.sql` | Fact and dimension tables |
| `sql/04_cortex/01_create_semantic_view.sql` | Semantic model for Intelligence |
| `sql/04_cortex/02_create_agent.sql` | Intelligence Agent definition |
| `sql/05_streamlit/01_create_dashboard.sql` | Streamlit app deployment |
| `streamlit/streamlit_app.py` | 4-page dashboard source |

## Adding a New Player Metric

1. Add the column to the appropriate DT in `sql/03_transformations/` (profiles for per-player, engagement for time-series)
2. Add the column to the downstream fact table in `sql/03_transformations/04_dynamic_tables_facts.sql`
3. Add a FACTS entry in `sql/04_cortex/01_create_semantic_view.sql` with synonyms and comment
4. Update the agent's `AI_SQL_GENERATION` instructions if the metric needs special query guidance
5. Add a display widget in the relevant Streamlit page
6. Redeploy: `EXECUTE IMMEDIATE FROM` the changed scripts, or rerun `deploy_all.sql`

## Snowflake Objects
- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `GAMING_PLAYER_ANALYTICS`
- Warehouse: `SFE_GAMING_PLAYER_ANALYTICS_WH`
- Raw tables: `RAW_PLAYERS`, `RAW_PLAYER_EVENTS`, `RAW_IN_APP_PURCHASES`, `RAW_PLAYER_FEEDBACK`
- Dynamic Tables: `DT_PLAYER_PROFILES`, `DT_SESSION_METRICS`, `DT_ENGAGEMENT_FEATURES`, `DT_FEEDBACK_ENRICHED`
- Analytics: `FACT_PLAYER_LIFETIME`, `FACT_DAILY_ENGAGEMENT`, `DIM_PLAYERS`, `DIM_DATES`
- Semantic View: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_GAMING_PLAYER_ANALYTICS`
- Agent: `PLAYER_ANALYTICS_AGENT`
- All objects have `COMMENT = 'DEMO: ... (Expires: 2026-04-24)'`

## Gotchas
- `SNOWFLAKE.CORTEX.SENTIMENT` does not work in Dynamic Tables; use `AI_CLASSIFY` with `['Positive', 'Negative', 'Neutral']` instead
- AI_EXTRACT `responseFormat` uses simple object format (`{'key': 'question'}`), not JSON schema
- Semantic View lives in `SEMANTIC_MODELS` schema, not `GAMING_PLAYER_ANALYTICS`
- FACTS must come before DIMENSIONS in semantic view definition (clause order matters)
- DT_ENGAGEMENT_FEATURES uses `TARGET_LAG = DOWNSTREAM` — it only refreshes when downstream DTs need it
- Minimum TARGET_LAG is 60 seconds; the demo uses 1 hour for cost efficiency
