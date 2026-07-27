---
name: artist-analytics
description: "Artist Analytics demo for Jade Hollow — music streaming, social media, income, and show momentum score. Triggers: artist analytics, music demo, jade hollow, momentum score, streaming demo, indie artist, tour analytics, social engagement music."
---

# Artist Analytics

## Purpose

Two-tier music artist analytics demo. Basic tier: Snowflake App Runtime dashboard (dark-themed, branded, Recharts visualizations). Pro tier: Snowflake Intelligence (CoWork) powered by a Cortex Agent over a semantic view, with momentum scores that show whether social engagement is building in each show city before the performance date.

Fictional artist: Jade Hollow (indie pop, Nashville, independent label).

## Architecture

```
DIM tables → FACT tables → KPI views + V_SHOW_MOMENTUM → SV_ARTIST_ANALYTICS → ARTIST_ANALYTICS_AGENT → Intelligence
                                                    ↓
                                     App Runtime (Next.js on SPCS)
                                     Deployed via GitHub Actions CI/CD
```

## Deployment Model

```
Push to main → GitHub Actions → OIDC auth → snow app deploy → stable URL
SE pastes deploy_all.sql → data + agent ready → app already live
```

No clone, no CLI, no npm required by the SE consuming the demo.

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Data layer deploy — paste into Snowsight, Run All |
| `teardown_all.sql` | Drops schema + warehouse, preserves SNOWFLAKE_EXAMPLE DB |
| `app-runtime/` | Next.js dashboard (App Runtime) |
| `app-runtime/snowflake.yml` | Deployment manifest for `snow app deploy` |
| `app-runtime/app.yml` | App metadata (label, description, icon) |
| `sql/00_cicd/01_service_user.sql` | OIDC service user for GitHub Actions (run once) |
| `sql/02_data/04_social.sql` | Contains the momentum boost multiplier (1.5x for cities within 14d) |
| `sql/03_views/02_momentum_score.sql` | V_SHOW_MOMENTUM definition — the centerpiece metric |
| `sql/04_cortex/01_semantic_view.sql` | SV_ARTIST_ANALYTICS — 4 logical tables |
| `sql/04_cortex/02_create_agent.sql` | ARTIST_ANALYTICS_AGENT with sample questions |
| `.github/workflows/deploy-artist-analytics.yml` | CI/CD workflow — auto-deploys on push to main |

## Snowflake Objects

| Object | Name |
|--------|------|
| Database | `SNOWFLAKE_EXAMPLE` |
| Schema | `SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS` |
| Warehouse | `SFE_ARTIST_ANALYTICS_WH` |
| Semantic View | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_ARTIST_ANALYTICS` |
| Application Service | `ARTIST_ANALYTICS` |
| Service User | `SFE_GITHUB_DEPLOY` (OIDC, for CI/CD) |

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

### How to modify the dashboard

1. Edit files in `app-runtime/` (Next.js / React)
2. Test locally: `cd app-runtime && npm run dev`
3. Push to `main` — GitHub Actions auto-deploys within ~5 min

### How to redeploy manually (fallback)

```bash
cd app-runtime && snow app deploy
```

## Gotchas

- **Show dates use `CURRENT_DATE()` at insert time.** If you insert the shows, wait 2 months, then regenerate the social data, the pre-show windows will be in the past and momentum scores will be NULL. Re-run `02_shows.sql` to push show dates forward again.
- **Momentum score NULL for all shows** usually means shows are all > 14 days out. NULL is correct when the pre-show window hasn't started — display as "Pre-window" in the UI.
- **Social REGION must exactly match DIM_SHOW.VENUE_CITY** for the momentum join to produce results. A typo (e.g., "Los Angeles" vs "Los Angeles, CA") will silently produce NULL momentum scores.
- **Semantic view DDL syntax:** `FACTS` and `DIMENSIONS` use `table_alias.column` prefixes. Derived view-level metrics have no table prefix. `AI_SQL_GENERATION '...'` replaces the YAML `custom_instructions` block.
- **V_INCOME_KPI depends on FACT_INCOME, which depends on FACT_DAILY_STREAMS.** Always run `03_streams.sql` before `05_income.sql`.
- **snowflake.yml must target a shared database** (not `USER$*`) for other SEs to access the deployed app. Requires App Runtime account administrator setup.
- **CI/CD OIDC subject is branch-locked.** If you rename the repo or deploy from a different branch, update the service user's WORKLOAD_IDENTITY SUBJECT.
- **Trial accounts don't support App Runtime.** Use a paid account.
