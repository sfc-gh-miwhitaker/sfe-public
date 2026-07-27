# Artist Analytics — Jade Hollow

Pair-programmed by SE Community + Cortex Code | **Expires: 2026-08-23**

**5-minute deploy → two-tier music analytics for an independent artist.** Paste, run, demo.

This is an "art of the possible" demo. A self-starting artist named Jade Hollow wants more useful metrics than what the streaming platforms surface. The basic tier gives a clean visual dashboard (streams, social, income). The pro tier lets the artist ask plain-English questions about their career data — including momentum scores that show whether fan engagement is building in each show city before the concert date.

## Quick Start

1. Open **Snowsight → New Worksheet**
2. Paste `deploy_all.sql`
3. Click **Run All** (~4 min)

**Basic tier:**
4. Navigate to **Projects → Streamlit → ARTIST_DASHBOARD**

**Pro tier (Snowflake Intelligence):**
4. Navigate to **AI & ML → Agents → ARTIST_ANALYTICS_AGENT → "Add to CoWork"**
5. Ask: *"Which city has the best momentum score for my upcoming shows?"*

## What It Proves

| Persona Question | What They See |
|---|---|
| "Can I get better metrics than Spotify For Artists?" | Streams, saves, listeners by platform with real royalty estimates |
| "What does my social engagement look like before a show?" | Momentum score: is fan activity in Nashville building or cooling? |
| "Where is my income actually coming from?" | Royalties vs merch vs sync — broken down by day |
| "Can I ask questions without building a dashboard?" | Yes — Intelligence answers in plain English, renders charts automatically |
| "Does this work with my real data?" | Same architecture, point it at real platform exports. Same 5-minute deploy. |

## Two Tiers

```
BASIC TIER — "The Dashboard"
  Streamlit app: Streams / Social / Income pages
  Share a link. No questions needed. Works for managers and accountants.
        ↓ upgrade
PRO TIER — "CoWork" (Snowflake Intelligence)
  Cortex Agent over a semantic view
  Ask anything about streams, social, income, or upcoming show momentum
  Dashboard available as a linked artifact
```

## Demo Script (Suggested Flow)

1. **Open the Streamlit dashboard.** Show the KPI tiles: streams, impressions, income. "This is what a manager gets."
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
| Streamlit | `SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.ARTIST_DASHBOARD` |

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
- **"Can the artist use this themselves?"** — Yes. Grant them USAGE on the schema and the Streamlit app. For Intelligence, they need their own account or CoWork access.

## Teardown

Paste `teardown_all.sql` into Snowsight → Run All. Drops everything except `SNOWFLAKE_EXAMPLE` database.

## Prerequisites

- `SYSADMIN` role (or equivalent)
- Any Snowflake edition (Standard or higher)
- `SFE_GIT_API_INTEGRATION` must exist in `SNOWFLAKE_EXAMPLE` (shared SE infra)

## Development Tools

- `AGENTS.md` — project context for AI coding assistants
- `.claude/skills/artist-analytics/` — project skill for Cortex Code / Claude Code
