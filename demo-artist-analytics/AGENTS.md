# Artist Analytics — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

```
DIM_ARTIST / DIM_PLATFORM / DIM_SOCIAL_PLATFORM / DIM_SHOW
        ↓                       ↓                      ↓
FACT_DAILY_STREAMS   FACT_SOCIAL_METRICS          FACT_INCOME
        ↓                       ↓                      ↓
  V_STREAM_KPI        V_SOCIAL_KPI              V_INCOME_KPI
                             ↓
                    V_SHOW_MOMENTUM  ← FACT_SOCIAL_METRICS × DIM_SHOW (region join)
                             ↓
             SV_ARTIST_ANALYTICS (semantic view — 4 logical tables)
                             ↓
              ARTIST_ANALYTICS_AGENT → Snowflake Intelligence (CoWork)
                             ↓
                    ARTIST_DASHBOARD (Streamlit — basic tier)
```

Data scope: 90 days of synthetic data. Show dates computed dynamically at insert time as `DATEADD('day', N, CURRENT_DATE())` so they stay in the future after each deploy.

## Snowflake Environment

| Object | Value |
|--------|-------|
| Database | `SNOWFLAKE_EXAMPLE` |
| Schema | `SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS` |
| Semantic View schema | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS` |
| Warehouse | `SFE_ARTIST_ANALYTICS_WH` |
| Streamlit | `SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.ARTIST_DASHBOARD` |
| Agent | `SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.ARTIST_ANALYTICS_AGENT` |

## Conventions

- All fact data is synthetic — GENERATOR + UNIFORM + RANDOM(). No external data sources required at deploy time.
- Show dates are always in the future (set relative to `CURRENT_DATE()` at insert time). Re-running `02_shows.sql` after a few weeks will push them forward.
- Momentum score is NULL for shows more than 14 days out (pre-show window hasn't started). This is correct behavior — surface it as "Pre-window" in the UI.
- `FACT_SOCIAL_METRICS.REGION` values must exactly match `DIM_SHOW.VENUE_CITY` for the momentum join to work. Current set: Nashville, Austin, Chicago, Los Angeles, New York.
- Social data includes a momentum boost multiplier built into the GENERATOR at insert time: any city within 14 days of a show gets 1.5× engagement. This makes the demo compelling out of the box.
- The Streamlit app uses warehouse runtime (not container runtime). `QUERY_WAREHOUSE` is `SFE_ARTIST_ANALYTICS_WH`.

## Key Commands

```sql
-- Deploy everything from scratch
-- Snowsight → paste deploy_all.sql → Run All

-- Teardown
-- Snowsight → paste teardown_all.sql → Run All

-- Verify row counts after deploy
SELECT
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_DAILY_STREAMS)  AS stream_rows,   -- expect 360
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_SOCIAL_METRICS) AS social_rows,  -- expect 1800
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_INCOME)         AS income_rows,  -- expect 90
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.V_SHOW_MOMENTUM)     AS shows;         -- expect 5

-- Check momentum scores
SELECT show_name, venue_city, days_until_show, momentum_score, momentum_label
FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.V_SHOW_MOMENTUM
ORDER BY show_date;
```

## When Helping

- **Adding a new show city:** Add a row to `DIM_SHOW` and add that city as a `VALUES` row in `04_social.sql`'s `regions` CTE. Re-run `04_social.sql` and `02_momentum_score.sql`.
- **Extending data to 180 days:** Change `ROWCOUNT => 90` to `ROWCOUNT => 180` in `03_streams.sql` and `04_social.sql`. The `income` table depends on `FACT_DAILY_STREAMS`, so run in order.
- **Adding a streaming platform:** Insert a row into `DIM_PLATFORM`, then the GENERATOR in `03_streams.sql` will include it automatically on next run (it cross-joins all platforms).
- **Semantic view column names:** The semantic view uses DDL syntax. FACTS and DIMENSIONS reference `table_alias.column_name`. METRICS use aggregation expressions on those facts.
- **Momentum score is all NULL:** Usually means show dates are all more than 14 days out. Either the shows were inserted earlier and dates expired, or the data was inserted long before the shows start. Re-run `02_shows.sql` to reset show dates to the current `CURRENT_DATE()` + offsets, then re-run `04_social.sql` to regenerate the momentum boost.
