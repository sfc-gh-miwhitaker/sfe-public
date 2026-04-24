# Deployment Guide

## Prerequisites

- Snowflake account with **Enterprise** edition (for Cortex AI functions)
- `SYSADMIN` + `ACCOUNTADMIN` role access
- Cortex AI enabled in your region

## Deploy (2 steps, ~10 minutes)

### Step 1 — Deploy in Snowsight

1. Open [Snowsight](https://app.snowflake.com)
2. Create a new SQL Worksheet
3. Paste the entire contents of [`deploy_all.sql`](../deploy_all.sql)
4. Click **Run All**

The script creates everything: schema, warehouse, tables, sample data, Dynamic Tables, AI enrichment, semantic view, Intelligence agent, Streamlit dashboard, sharing views, and budget alert task.

### Step 2 — Open the Dashboard

Navigate to **Projects > Streamlit** in Snowsight and open **MUSIC_MARKETING_APP**.

## What Gets Created

| Object | Type | Purpose |
|--------|------|---------|
| `SNOWFLAKE_EXAMPLE.MUSIC_MARKETING` | Schema | All demo objects |
| `SFE_MUSIC_MARKETING_WH` | Warehouse | X-SMALL compute |
| `RAW_ARTISTS` | Table | 50 artists across 5 genres |
| `RAW_MARKETING_BUDGET` | Table | Budget allocations (editable via Streamlit) |
| `RAW_MARKETING_SPEND` | Table | Daily spend transactions |
| `RAW_CAMPAIGNS` | Table | Campaign metadata (intentionally messy) |
| `RAW_STREAMS` | Table | Daily streaming counts |
| `RAW_ROYALTIES` | Table | Monthly royalty payments |
| `DIM_ARTIST` | Dynamic Table | Artist dimension |
| `DIM_CAMPAIGN` | Dynamic Table | AI-enriched campaign dimension |
| `DIM_CHANNEL` | Dynamic Table | Marketing channel dimension |
| `DIM_TIME_PERIOD` | Dynamic Table | Date dimension |
| `FACT_MARKETING_SPEND` | Dynamic Table | Daily spend with budget comparison |
| `FACT_CAMPAIGN_PERFORMANCE` | Dynamic Table | Campaign ROI metrics |
| `FACT_STREAMS` | Dynamic Table | Streaming facts |
| `FACT_ROYALTIES` | Dynamic Table | Royalty facts |
| `SV_MUSIC_MARKETING` | Semantic View | Semantic model (in SEMANTIC_MODELS schema) |
| `MUSIC_MARKETING_AGENT` | Agent | Snowflake Intelligence agent |
| `MUSIC_MARKETING_APP` | Streamlit | 5-page dashboard |
| `V_BUDGET_ALERTS` | View | Budget overspend monitor |
| `V_PARTNER_CAMPAIGN_SUMMARY` | Secure View | Partner-facing campaign data |
| `V_PARTNER_STREAMING_SUMMARY` | Secure View | Partner-facing streaming data |
| `BUDGET_ALERT_LOG` | Table | Alert history |
| `BUDGET_ALERT_TASK` | Task | Hourly overspend check |
