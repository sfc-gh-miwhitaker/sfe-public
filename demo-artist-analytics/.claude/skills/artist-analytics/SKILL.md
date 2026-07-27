---
name: artist-analytics
description: "Artist Analytics demo for Jade Hollow — music streaming, social media, income, and show momentum score. Triggers: artist analytics, music demo, jade hollow, momentum score, streaming demo, indie artist, tour analytics, social engagement music."
---

# Artist Analytics

## Purpose

Two-tier music artist analytics demo. Basic tier: Streamlit KPI dashboard (streams, social impressions, income). Pro tier: Snowflake Intelligence (CoWork) powered by a Cortex Agent over a semantic view, with momentum scores that show whether social engagement is building in each show city before the performance date.

Fictional artist: Jade Hollow (indie pop, Nashville, independent label).

## Architecture

```
DIM tables → FACT tables → KPI views + V_SHOW_MOMENTUM → SV_ARTIST_ANALYTICS → ARTIST_ANALYTICS_AGENT → Intelligence
                                                                                              ↓
                                                                               ARTIST_DASHBOARD (Streamlit)
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Single-entry deploy — paste into Snowsight, Run All |
| `teardown_all.sql` | Drops schema + warehouse, preserves SNOWFLAKE_EXAMPLE DB |
| `sql/02_data/04_social.sql` | Contains the momentum boost multiplier (1.5× for cities within 14d of a show) |
| `sql/03_views/02_momentum_score.sql` | V_SHOW_MOMENTUM definition — the centerpiece metric |
| `sql/04_cortex/01_semantic_view.sql` | SV_ARTIST_ANALYTICS — 4 logical tables (streams, social, income, shows) |
| `sql/04_cortex/02_create_agent.sql` | ARTIST_ANALYTICS_AGENT with sample questions |
| `app/streamlit_app.py` | Landing page with KPI tiles and upcoming shows table |
| `app/pages/1_Streams.py` | Streaming trends by platform |
| `app/pages/2_Social.py` | Social impressions and engagement rate |
| `app/pages/3_Income.py` | Royalties, merch, sync income breakdown |

## Snowflake Objects

| Object | Name |
|--------|------|
| Database | `SNOWFLAKE_EXAMPLE` |
| Schema | `SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS` |
| Warehouse | `SFE_ARTIST_ANALYTICS_WH` |
| Semantic View | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_ARTIST_ANALYTICS` |

## Extension Playbook

### How to add a new show city

1. Add a row to `DIM_SHOW` in `sql/02_data/02_shows.sql` with the new `VENUE_CITY` value
2. Add the same city string to the `regions` VALUES CTE in `sql/02_data/04_social.sql`
3. Re-run `02_shows.sql`, then `04_social.sql`, then `02_momentum_score.sql`
4. Verify: `SELECT * FROM V_SHOW_MOMENTUM ORDER BY show_date` — new city should appear

### How to extend the data window beyond 90 days

1. In `sql/02_data/03_streams.sql`: change `ROWCOUNT => 90` to the desired number of days
2. In `sql/02_data/04_social.sql`: change `ROWCOUNT => 90` to match
3. Re-run both scripts; then re-run `05_income.sql` (it reads from FACT_DAILY_STREAMS)
4. Re-run `01_kpi_views.sql` (no change needed, but good hygiene)

## Gotchas

- **Show dates use `CURRENT_DATE()` at insert time.** If you insert the shows, wait 2 months, then regenerate the social data, the pre-show windows will be in the past and momentum scores will be NULL. Re-run `02_shows.sql` to push show dates forward again.
- **Momentum score NULL for all shows** usually means shows are all > 14 days out. NULL is correct when the pre-show window hasn't started — display as "Pre-window" in the UI.
- **Social REGION must exactly match DIM_SHOW.VENUE_CITY** for the momentum join to produce results. A typo (e.g., "Los Angeles" vs "Los Angeles, CA") will silently produce NULL momentum scores.
- **Semantic view DDL syntax:** `FACTS` and `DIMENSIONS` use `table_alias.column` prefixes. Derived view-level metrics have no table prefix. `AI_SQL_GENERATION '...'` replaces the YAML `custom_instructions` block.
- **V_INCOME_KPI depends on FACT_INCOME, which depends on FACT_DAILY_STREAMS.** Always run `03_streams.sql` before `05_income.sql`.
- **Streamlit uses warehouse runtime** (not container runtime). The `QUERY_WAREHOUSE` parameter sets the compute for both app code and SQL queries on the same XS warehouse.
