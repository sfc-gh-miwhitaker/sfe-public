# Media Campaign Analytics

Pair-programmed by SE Community + Cortex Code | **Expires: 2026-08-12**

**5-minute deploy → live AI chat over advertising data.** Paste, run, demo.

This is an "art of the possible" demo. The audience asks plain-English questions about campaign performance and gets instant answers with charts — no dashboards, no SQL, no external tools. The goal is to create a *"I want that for my team"* reaction, then follow up with technical depth after interest is established.

## Quick Start

1. Open **Snowsight → New Worksheet**
2. Paste `deploy_all.sql`
3. Click **Run All** (~5 min)
4. Navigate to **AI & ML → Agents → MEDIA_CAMPAIGN_AGENT → "Add to CoWork"**
5. Ask: *"Which channel has the highest ROAS this year?"*

## What It Proves

| Customer Question | What They See |
|---|---|
| "Can AI answer questions about *my* data?" | Yes — type a question, get an answer in seconds |
| "Can it search documents too?" | Yes — briefs, copy, strategy notes, all searchable in the same chat |
| "Do I need external tools?" | No — runs entirely inside Snowflake's perimeter |
| "Is it accurate?" | Semantic view + verified queries = reliable, governed answers |
| "How hard is this to set up?" | One file, 5 minutes, X-Small warehouse |
| "What about security?" | Same RBAC, same audit trail as their existing data |

## Demo Script (Suggested Flow)

1. **Open with a number.** Start in the agent chat, ask "What's our total spend by channel this month?" — let the audience see the answer first.
2. **Show a chart.** Ask "How has Connected TV spend trended by quarter?" — the agent renders a line chart automatically.
3. **Show document search.** Ask "What was the creative strategy for Client Alpha's social campaigns?" — the agent searches unstructured briefs and returns the strategy, cited by document title.
4. **The killer moment.** Ask a hybrid question: "Client Delta's CTV spend is high — why did we choose that channel for them?" — the agent pulls both the spend data AND the channel strategy rationale in one response.
5. **Show an edge case.** Ask about CTR for CTV — the agent knows it's impression-only and explains why click metrics don't apply.
6. **Only then explain the architecture** (if the audience wants it): structured data + unstructured docs → one agent, two tools.

## What Gets Created

| Object | Name |
|--------|------|
| Database | `SNOWFLAKE_EXAMPLE` (shared, if not exists) |
| Schema | `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS` |
| Warehouse | `SFE_MEDIA_CAMPAIGN_WH` (XS, auto-suspend 60s) |
| Tables | `DIM_CLIENT`, `DIM_CHANNEL`, `DIM_CAMPAIGN`, `FACT_DAILY_PERFORMANCE` |
| View | `V_CAMPAIGN_KPI` |
| Documents | `DOC_CAMPAIGN_CONTENT` (briefs, copy, strategy, notes) |
| Search Service | `CAMPAIGN_DOCS_SEARCH` (Cortex Search) |
| Semantic View | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS` |
| Agent | `MEDIA_CAMPAIGN_AGENT` (analytics + doc search) |

## Handling Live Demo Moments

- **"These numbers don't look realistic"** — It's synthetic data. The point is the interaction pattern, not the values. With their real data, the numbers are theirs.
- **"CTR is NULL for Connected TV"** — That's correct. CTV is impression-only. Demo this as a feature: "The agent understands channel semantics."
- **"Can it handle our data?"** — Yes. Point a semantic view at their tables, define their metrics, done. Same architecture, different data.
- **"What about our documents?"** — Same approach. Load docs into a table, create a Cortex Search Service, wire it into the agent. One more tool declaration in the spec.
- **"What does it cost?"** — X-Small warehouse + per-query Cortex credits + search service refresh (minimal for a demo corpus).

## Teardown

Paste `teardown_all.sql` into Snowsight → Run All. Drops everything except the shared `SNOWFLAKE_EXAMPLE` database.

## Prerequisites

- `SYSADMIN` role (or equivalent)
- Any Snowflake edition (Standard or higher)

## Development Tools

- `AGENTS.md` — project context for AI coding assistants
- `.claude/skills/media-campaign-analytics/` — project skill for Cortex Code / Claude Code
