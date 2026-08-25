# ELI5: Cortex AI Cost Controls

## One Sentence

A dashboard that shows you who's spending your AI credits, how fast, and whether anyone has been automatically cut off.

## The Story

Imagine you run a restaurant where every table can order from an expensive menu (AI models). You need to know:

- **How much food is going out?** (total AI credit spend)
- **Which tables are ordering the most?** (per-user attribution)
- **Did anyone hit their tab limit?** (per-user quota enforcement)
- **Are we on track to blow the monthly food budget?** (trend analysis)

This demo builds that restaurant manager's dashboard — but for Snowflake AI services instead of food.

## Cast of Characters

| Thing | What It Does |
|-------|-------------|
| **Materialized tables** | Pre-cooked summaries of raw usage data, refreshed every 15 minutes |
| **SNOWFLAKE.CORE.QUOTA** | The "tab limit" — Snowflake's native per-user spending cap |
| **ACCOUNT_USAGE views** | The raw billing log — every AI call ever made in your account |
| **Refresh task** | The prep cook who re-summarizes the data every 15 minutes |
| **Next.js app** | The dashboard screen hanging on the restaurant wall |
| **Recharts** | The charting library that draws the pretty graphs |

## What Changed (vs. the old version)

The old version built custom enforcement from scratch (stored procedures, audit tables, scheduled tasks). Now Snowflake does all of that natively with per-user quotas — automatic blocking, notifications, projected-spend alerts. So the demo was rebuilt to show the native feature instead of reinventing it.

The old version also used Streamlit. The new version uses Snowflake App Runtime (React/Next.js) — faster, more flexible, deploys the same way.

## Watch-outs

- Data takes ~1 hour to show up after AI calls are made (ACCOUNT_USAGE lag)
- The refresh task ships turned off — you have to flip the switch yourself
- Quota setup requires a special role (QUOTA_CREATOR) — the script handles failure gracefully
- The app is read-only — to change quota limits, use Snowsight or SQL

## One Takeaway

You don't need to build custom AI cost enforcement anymore. Snowflake has per-user quotas that block users automatically when they hit their limit. This demo shows you what that looks like in practice and adds the attribution visibility that quotas alone don't provide.
