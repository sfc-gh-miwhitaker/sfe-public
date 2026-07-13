# Media Campaign Analytics

Pair-programmed by SE Community + Cortex Code | **Expires: 2026-08-12**

Cortex Agent demo — natural language exploration of paid media campaign performance. Built for media agencies and marketing analytics personas. No Streamlit; the UI is Snowflake Intelligence (AI & ML → Agents).

## Quick Start

1. Open **Snowsight → New Worksheet**
2. Paste `deploy_all.sql`
3. Click **Run All** (~5 min)
4. Navigate to **AI & ML → Agents → MEDIA_CAMPAIGN_AGENT → "Add to CoWork"**
5. Ask: *"Which channel has the highest ROAS this year?"*

## What Gets Created

| Object | Name |
|--------|------|
| Database | `SNOWFLAKE_EXAMPLE` (shared, if not exists) |
| Schema | `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS` |
| Warehouse | `SFE_MEDIA_CAMPAIGN_WH` (XS, auto-suspend 60s) |
| Tables | `DIM_CLIENT`, `DIM_CHANNEL`, `DIM_CAMPAIGN`, `FACT_DAILY_PERFORMANCE` |
| View | `V_CAMPAIGN_KPI` |
| Semantic View | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS` |
| Agent | `MEDIA_CAMPAIGN_AGENT` |

## Architecture

```
DIM_CLIENT ─────────────────────────────────┐
DIM_CHANNEL ──────────────────────────┐     │
DIM_CAMPAIGN (budget, status, dates) ─┼─────┤
FACT_DAILY_PERFORMANCE (perf rows) ───┘     │
         ↓                                  │
  V_CAMPAIGN_KPI (joined, computed ratios)  │
         ↓                                  │
  SV_MEDIA_CAMPAIGN_ANALYTICS (semantic layer)
         ↓
  MEDIA_CAMPAIGN_AGENT (Cortex Agent)
         ↓
  Snowflake Intelligence UI
```

## Data

Synthetic dataset generated at deploy time via `GENERATOR`:

- **20 clients** across 5 verticals (Retail, Finance, Healthcare, Technology, Consumer Goods)
- **5 channels**: Paid Search, Social Media, Display, Connected TV, Streaming Audio
- **~300 campaigns** with realistic budgets and date ranges
- **Daily fact rows** from Jan 2025 through Jun 2026

Connected TV has zero clicks/conversions by design (impression-only medium).

## Teardown

Paste `teardown_all.sql` into Snowsight and Run All. Drops project schema, agent, semantic view, and warehouse. Preserves the shared `SNOWFLAKE_EXAMPLE` database.

## Prerequisites

- `SYSADMIN` role (or equivalent with CREATE DATABASE/SCHEMA/WAREHOUSE privileges)
- Any Snowflake edition (Standard or higher)
