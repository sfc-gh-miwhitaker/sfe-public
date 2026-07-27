# Artist Analytics — Jade Hollow

Pair-programmed by SE Community + Cortex Code | **Expires: 2026-08-23**

**Two-tier music analytics for an independent artist.** A branded web dashboard (App Runtime) + natural-language intelligence (Cortex Agent).

A self-starting artist named Jade Hollow wants more useful metrics than what the streaming platforms surface. The basic tier is a modern branded dashboard deployed as a Snowflake App (streams, social, income, show momentum). The pro tier lets the artist ask plain-English questions about their career data — including momentum scores that show whether fan engagement is building in each show city before the concert date.

## Quick Start

1. Open **Snowsight → New Worksheet**
2. Paste `deploy_all.sql`, click **Run All** (~4 min)
3. Open the dashboard: **Snowsight → Apps → ARTIST_ANALYTICS**
4. Pro tier: **AI & ML → Agents → ARTIST_ANALYTICS_AGENT → "Add to CoWork"**

> The App Runtime dashboard is deployed automatically via GitHub Actions on every
> push to `main`. No clone or CLI required. See `sql/00_cicd/` for setup details.

### First-time setup (one-time, per account)

If this is the first deploy to a new account, an admin must:
1. Complete [App Runtime account administrator setup](https://docs.snowflake.com/en/developer-guide/snowflake-app-runtime/admin-setup) in Snowsight
2. Run `sql/00_cicd/01_service_user.sql` to create the OIDC service user
3. Add `SNOWFLAKE_ACCOUNT` to GitHub repo secrets

### Manual deploy (fallback, if CI hasn't run)

```bash
cd app-runtime
npm install
snow app deploy
```

## What It Proves

| Persona Question | What They See |
|---|---|
| "Can I get better metrics than Spotify For Artists?" | Streams, saves, listeners by platform with real royalty estimates |
| "What does my social engagement look like before a show?" | Momentum score: is fan activity in Nashville building or cooling? |
| "Where is my income actually coming from?" | Royalties vs merch vs sync — broken down by day |
| "Can I ask questions without building a dashboard?" | Yes — Intelligence answers in plain English, renders charts automatically |
| "Does this work with my real data?" | Same architecture, point it at real platform exports. Same deploy. |

## Two Tiers

```
BASIC TIER — "The Dashboard" (Snowflake App Runtime)
  Modern branded web app: Overview / Streams / Social / Income tabs
  Dark theme, Recharts visualizations, time-period selector
  Deployed as a Snowflake App (SPCS container)
        ↓ upgrade
PRO TIER — "CoWork" (Snowflake Intelligence)
  Cortex Agent over a semantic view
  Ask anything about streams, social, income, or upcoming show momentum
```

## Demo Script (Suggested Flow)

1. **Open the App Runtime dashboard.** Show the KPI tiles: streams, impressions, income. Click through tabs. "This is what a manager gets — branded, modern, no code needed from the artist."
2. **Switch to Snowflake Intelligence.** Ask: *"What were my total streams last month across all platforms?"*
3. **Show a chart.** Ask: *"Which streaming platform is growing the fastest?"* — agent renders a line chart.
4. **The momentum moment.** Ask: *"My Nashville show is in two weeks — what's my momentum score there compared to my other cities?"*
5. **Follow-up.** Ask: *"Which city needs the most attention before showtime?"*
6. **Explain architecture only if asked:** synthetic data shaped like Luminate + Socialgist feeds → views → semantic view → agent → Intelligence.

## What Gets Created

| Object | Name |
|--------|------|
| Database | `SNOWFLAKE_EXAMPLE` (shared, if not exists) |
| Schema | `SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS` |
| Warehouse | `SFE_ARTIST_ANALYTICS_WH` (XS, auto-suspend 60s) |
| Dimensions | `DIM_ARTIST`, `DIM_PLATFORM`, `DIM_SOCIAL_PLATFORM`, `DIM_SHOW` |
| Facts | `FACT_DAILY_STREAMS`, `FACT_SOCIAL_METRICS`, `FACT_INCOME` |
| Views | `V_STREAM_KPI`, `V_SOCIAL_KPI`, `V_INCOME_KPI`, `V_SHOW_MOMENTUM` |
| Semantic View | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_ARTIST_ANALYTICS` |
| Agent | `ARTIST_ANALYTICS_AGENT` |
| Snowflake App | `ARTIST_ANALYTICS` (deployed via GitHub Actions CI/CD) |

## Momentum Score

The momentum score is the centerpiece of the pro tier. For each upcoming show:

- **Pre-show window:** average daily social engagements in the 14 days before the show date
- **Baseline window:** average daily social engagements in the 30 days ending 15 days before the show
- **Score:** `(pre-show avg / baseline avg) × 100`

Score > 100 = engagement is building (fan base is activating).
Score < 100 = cooling off (may need a social push or targeted ads).
Score = NULL = the pre-show window hasn't started yet (show is more than 14 days away).

## Handling Live Demo Moments

- **"These numbers look made up."** — They are. The interaction pattern is the point. With real data from platform exports (Luminate, Socialgist TikTok API), the numbers are theirs.
- **"How do I get real streaming data?"** — Luminate offers chart and consumption data on the Snowflake Marketplace (`GZT0Z127WD78`). Platform-level export APIs (Spotify for Artists, etc.) load into tables with the same schema.
- **"How do I get real social data?"** — Socialgist publishes TikTok artist data on the Marketplace (`GZT1Z25BQQ`). Instagram, YouTube, X via their official APIs.
- **"What about my city — it's not in the demo."** — Add a row to `DIM_SHOW` and seed `FACT_SOCIAL_METRICS` with that region. Same schema.
- **"Can the artist use this themselves?"** — Yes. Grant them USAGE on the schema. For the dashboard, the app handles auth. For Intelligence, they need CoWork access.

## Teardown

```bash
# App Runtime (if deployed):
cd app-runtime && snow app teardown

# Data layer:
# Paste teardown_all.sql into Snowsight → Run All
```

Drops everything except `SNOWFLAKE_EXAMPLE` database.

## Prerequisites

- `SYSADMIN` role (or equivalent)
- Any Snowflake edition (Standard or higher) — trial accounts don't support App Runtime
- `SFE_GIT_API_INTEGRATION` must exist in `SNOWFLAKE_EXAMPLE` (shared SE infra)
- GitHub Actions OIDC service user (`sql/00_cicd/01_service_user.sql`) — run once per account
- Account administrator setup for Snowflake App Runtime — run once per account

## Development Tools

- `AGENTS.md` — project context for AI coding assistants
- `.claude/skills/artist-analytics/` — project skill for Cortex Code / Claude Code
- `.github/workflows/deploy-artist-analytics.yml` — CI/CD workflow (auto-deploys on push to main)
