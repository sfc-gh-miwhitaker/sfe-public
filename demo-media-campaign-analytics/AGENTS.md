# Media Campaign Analytics — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Four-table data model → flattened KPI view → Semantic View → Cortex Agent

```
DIM_CLIENT ─────────────────────────────────┐
DIM_CHANNEL ──────────────────────────┐     │
DIM_CAMPAIGN (budget, status, dates) ─┼─────┤
FACT_DAILY_PERFORMANCE (perf rows) ───┘     │
         ↓                                  │
  V_CAMPAIGN_KPI (joined, computed ratios)  │
         ↓                                  │
  SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS
         ↓
  MEDIA_CAMPAIGN_ANALYTICS.MEDIA_CAMPAIGN_AGENT
         ↓
  Snowflake Intelligence UI (AI & ML > Agents)
```

## Snowflake Environment

- Database: `SNOWFLAKE_EXAMPLE` (created by deploy_all.sql if not exists)
- Schema: `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS`
- Semantic View: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS`
- Agent: `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.MEDIA_CAMPAIGN_AGENT`
- Warehouse: `SFE_MEDIA_CAMPAIGN_WH` (XSmall, auto-suspend 60s)

## Conventions

- All objects prefixed by schema — no `SFE_` on project tables/views
- `SFE_` prefix only on account-level objects (warehouse, git integration)
- `daily_budget_allocation` = campaign.budget / campaign_duration_days (denormalized into fact for clean budget utilization metric)
- CTR, CVR, ROAS, CPM, CPC are derived metrics in the semantic view (not pre-computed in views)
- CTV (Connected TV) has 0 clicks by design — verified queries must handle NULLIF division

## Key Commands

```bash
# Deploy (paste deploy_all.sql into Snowsight, click Run All)
# Teardown (paste teardown_all.sql into Snowsight, click Run All)
# Test agent: AI & ML > Agents > MEDIA_CAMPAIGN_AGENT
```
