---
name: demo-music-label-marketing-analytics
description: "Music label marketing analytics with AI enrichment, spreadsheet-style budget entry, and Intelligence agent. Triggers: music marketing, Apex Records, budget tracking, AI_CLASSIFY, AI_EXTRACT, campaign ROI, st.data_editor, marketing analytics, spreadsheet Snowflake."
---

# Music Label Marketing Analytics -- Demo Guide

## Purpose

Marketing analytics platform for Apex Records demonstrating Dynamic Tables, Cortex AI enrichment (AI_CLASSIFY + AI_EXTRACT), a spreadsheet-style Streamlit budget entry page, Semantic Views, and a Snowflake Intelligence agent.

## Architecture

```
RAW_ARTISTS, RAW_CAMPAIGNS, RAW_MARKETING_BUDGET, RAW_MARKETING_SPEND, RAW_STREAMS, RAW_ROYALTIES
       │
       ├─── DIM_ARTIST, DIM_CHANNEL, DIM_TIME_PERIOD (Dynamic Tables)
       ├─── DIM_CAMPAIGN + AI_CLASSIFY + AI_EXTRACT (Dynamic Table)
       ├─── FACT_MARKETING_SPEND, FACT_CAMPAIGN_PERFORMANCE, FACT_STREAMS, FACT_ROYALTIES (Dynamic Tables)
       │
       ├─── SV_MUSIC_MARKETING (Semantic View in SEMANTIC_MODELS schema)
       │         ├── Intelligence Agent (natural-language queries)
       │         └── Streamlit Dashboard (5 pages)
       │
       ├─── V_PARTNER_CAMPAIGN_SUMMARY, V_PARTNER_STREAMING_SUMMARY (Secure Views)
       └─── BUDGET_ALERT_TASK (hourly overspend monitor)

Streamlit Budget Entry page writes back to RAW_MARKETING_BUDGET via session.sql() UPDATE.
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Single entry point for Snowsight deployment |
| `sql/01_setup/` | Schema and warehouse creation |
| `sql/02_data/` | Raw tables and GENERATOR-based sample data |
| `sql/03_transformations/` | Dynamic Tables (dimensions, facts, AI enrichment) |
| `sql/04_cortex/` | Semantic View and Intelligence Agent |
| `sql/05_streamlit/` | Streamlit deployment |
| `sql/06_activation/` | Secure views and budget alert task |
| `streamlit/streamlit_app.py` | 5-page dashboard with st.data_editor budget entry |

## Extension Playbook: Adding a New Dashboard Page

1. Add a new entry to the `PAGES` list in `streamlit/streamlit_app.py`
2. Add an `elif page == PAGES[N]:` block with the page logic
3. Query data using `run_query("SELECT ... FROM ...")`
4. Use `st.metric`, `st.dataframe`, `st.bar_chart`, etc. for visualization
5. No SQL changes needed unless the page needs a new view

## Extension Playbook: Adding a New AI-Enriched Field

1. Add the AI_CLASSIFY or AI_EXTRACT call to `sql/03_transformations/03_ai_enrichment.sql` in the DIM_CAMPAIGN query
2. Add a COALESCE-based `resolved_*` column that prefers the original value when present
3. Add the new dimension to `sql/04_cortex/01_create_semantic_view.sql` with synonyms and comment
4. Update the agent sample questions if the new field enables new question types
5. Rebuild: the Dynamic Table auto-refreshes; redeploy semantic view and agent manually

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.MUSIC_MARKETING` |
| Warehouse | `SFE_MUSIC_MARKETING_WH` |
| Dynamic Tables | `DIM_ARTIST`, `DIM_CAMPAIGN`, `DIM_CHANNEL`, `DIM_TIME_PERIOD`, `FACT_MARKETING_SPEND`, `FACT_CAMPAIGN_PERFORMANCE`, `FACT_STREAMS`, `FACT_ROYALTIES` |
| Semantic View | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MUSIC_MARKETING` |
| Agent | `MUSIC_MARKETING_AGENT` |
| Streamlit | `MUSIC_MARKETING_APP` |

## Gotchas

- FACTS-before-DIMENSIONS ordering in semantic view DDL is required by Snowflake
- AI_CLASSIFY returns `{labels: [...]}` — access via `:labels[0]::VARCHAR`
- AI_EXTRACT returns `{error: null, response: {...}}` — access via `:response:field::VARCHAR`
- Streamlit uses `FROM` with Git repo stage (not deprecated `ROOT_LOCATION`)
- Budget Entry page filters to current month forward — if no data exists for the current period, the grid will be empty
- The `resolved_*` columns use COALESCE(original, ai_value) — original data always wins when present
- BUDGET_ALERT_TASK must be explicitly RESUME'd after creation
