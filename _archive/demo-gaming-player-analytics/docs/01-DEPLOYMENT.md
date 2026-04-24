# Deployment Guide

## Prerequisites

- Snowflake **Enterprise** edition (required for Cortex AI functions)
- `SYSADMIN` and `ACCOUNTADMIN` role access
- Cortex AI enabled in your region ([check availability](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions#availability))

## Deploy

1. Open **Snowsight** (the Snowflake web interface)
2. Create a new **SQL Worksheet**
3. Paste the contents of [`deploy_all.sql`](../deploy_all.sql)
4. Click **Run All** (the play button with two arrows)

Deployment takes approximately 10 minutes. The AI enrichment Dynamic Tables (player cohort classification and feedback sentiment/topic extraction) account for most of the time.

## What Gets Created

| Object Type | Name | Purpose |
|---|---|---|
| Schema | `SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS` | Demo schema |
| Warehouse | `SFE_GAMING_PLAYER_ANALYTICS_WH` | Demo compute (X-SMALL) |
| Table | `RAW_PLAYERS` | 500 synthetic player profiles |
| Table | `RAW_PLAYER_EVENTS` | ~50,000 telemetry events |
| Table | `RAW_IN_APP_PURCHASES` | ~2,000 purchase transactions |
| Table | `RAW_PLAYER_FEEDBACK` | 500 free-text feedback entries |
| Dynamic Table | `DT_PLAYER_PROFILES` | Player profiles with AI cohort labels |
| Dynamic Table | `DT_SESSION_METRICS` | Daily session aggregates |
| Dynamic Table | `DT_ENGAGEMENT_FEATURES` | Rolling engagement indicators |
| Dynamic Table | `DT_FEEDBACK_ENRICHED` | Feedback with AI sentiment + topics |
| Dynamic Table | `DIM_PLAYERS` | Player dimension |
| Table | `DIM_DATES` | Date dimension (static) |
| Dynamic Table | `FACT_PLAYER_LIFETIME` | Per-player lifetime value and risk |
| Dynamic Table | `FACT_DAILY_ENGAGEMENT` | Daily cohort-level metrics |
| Semantic View | `SV_GAMING_PLAYER_ANALYTICS` | Semantic model for Intelligence |
| Agent | `PLAYER_ANALYTICS_AGENT` | Natural language query interface |
| Streamlit App | `GAMING_PLAYER_ANALYTICS_APP` | 4-page analytics dashboard |

## Estimated Costs

| Component | Est. Credits | Notes |
|-----------|-------------|-------|
| Sample data load | ~0.5 | One-time insert via GENERATOR |
| Cortex AI enrichment | ~1.5 | AI_CLASSIFY + AI_EXTRACT on 1,000 rows |
| Dynamic Table refresh | ~0.5 | Initial refresh of all 6 DTs |
| Storage | Minimal | <10 MB synthetic data |
| **Total** | **~2.5** | Single deployment run |
