# Cortex Agent Cost

![Expires](https://img.shields.io/badge/Expires-2026--04--22-orange)

> TOOL PROJECT - EXPIRES: 2026-04-22
> This tool uses Snowflake features current as of March 2026.

Granular cost reporting and forecasting for Cortex Agent and Snowflake Intelligence usage with per-model token and credit breakdowns.

**Pair-programmed by:** SE Community + Cortex Code
**Created:** 2026-03-23 | **Expires:** 2026-04-22 | **Status:** ACTIVE

## Brand New to GitHub or Cortex Code?

Start with the [Getting Started Guide](../guide-coco-setup/) -- it walks you through downloading the code and installing Cortex Code (the AI assistant that will help you with everything else).

## First Time Here?

1. **Deploy** - Copy `deploy_all.sql` into Snowsight, click "Run All"
2. **Open** - Navigate to Projects > Streamlit > CORTEX_AGENT_COST_APP
3. **Explore** - Browse the 5-page dashboard (Overview, Agent Deep Dive, Model Breakdown, User Attribution, Forecasting)
4. **Cleanup** - Run `teardown_all.sql` when done

## What This Does

Zooms into the `TOKENS_GRANULAR` and `CREDITS_GRANULAR` arrays from `CORTEX_AGENT_USAGE_HISTORY` and `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` to show:

- **Per-model credit and token breakdown** within agent orchestration calls
- **Cache efficiency analysis** (cache read tokens vs total input tokens)
- **Per-agent cost comparison** across all agents in your account
- **Per-user spend attribution** to identify top consumers
- **Cost forecasting** with growth rate scenario planning

## Architecture

```
ACCOUNT_USAGE
  ├─ CORTEX_AGENT_USAGE_HISTORY
  └─ SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
          │
    Detail Views ──► Combined View ──► Granular Views ──► Summary Views
                                       (LATERAL FLATTEN)
          │
    Streamlit Dashboard (5 pages)
```

## What Gets Deployed

| Object | Type | Purpose |
|--------|------|---------|
| `SNOWFLAKE_EXAMPLE.CORTEX_AGENT_COST` | Schema | All project objects |
| `SFE_CORTEX_AGENT_COST_WH` | Warehouse | XSmall, auto-suspend 60s |
| `AGENT_COST_CONFIG` | Table | Lookback days, credit cost USD |
| `V_AGENT_DETAIL` | View | Cortex Agent usage (90-day window) |
| `V_INTELLIGENCE_DETAIL` | View | Snowflake Intelligence usage (90-day window) |
| `V_AGENT_COMBINED` | View | Union of both sources |
| `V_TOKEN_GRANULAR` | View | Flattened per-model token breakdown |
| `V_CREDIT_GRANULAR` | View | Flattened per-model credit breakdown |
| `V_DAILY_SUMMARY` | View | Daily aggregation by agent/user |
| `V_AGENT_COST_SUMMARY` | View | Per-agent totals and averages |
| `V_MODEL_COST_SUMMARY` | View | Per-model cost analysis |
| `V_USER_AGENT_SPEND` | View | Per-user per-agent attribution |
| `V_CACHE_EFFICIENCY` | View | Cache read token ratio by model |
| `V_FORECAST_BASE` | View | Daily totals for forecasting |
| `CORTEX_AGENT_COST_APP` | Streamlit | 5-page dashboard |

## Prerequisites

- `ACCOUNTADMIN` role (for API integration creation)
- Account with Cortex Agent or Snowflake Intelligence usage data
- ACCOUNT_USAGE views lag up to 45 minutes — recent activity may not appear immediately

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skill teaching the AI this project's patterns
- **Cortex Code in Snowsight** -- Open in a Workspace for AI-assisted development
- **Cursor** -- Open locally for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
