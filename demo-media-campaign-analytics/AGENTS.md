# Media Campaign Analytics — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Purpose

Art-of-the-possible demo. The deliverable is a *reaction* — "I want that for my team" — not a teaching moment about architecture. Deploy fast, demo the chat experience, follow up with depth only when asked.

## Architecture

```
DIM_CLIENT / DIM_CHANNEL / DIM_CAMPAIGN / FACT_DAILY_PERFORMANCE
         ↓ (joined in)
  V_CAMPAIGN_KPI
         ↓ (semantic layer)
  SV_MEDIA_CAMPAIGN_ANALYTICS
         ↓ (agent)
  MEDIA_CAMPAIGN_AGENT → Snowflake Intelligence UI
```

The audience sees only the last step. Everything else is scaffolding.

## Snowflake Environment

- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS`
- Semantic View: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS`
- Agent: `SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.MEDIA_CAMPAIGN_AGENT`
- Warehouse: `SFE_MEDIA_CAMPAIGN_WH` (XSmall, auto-suspend 60s)

## Conventions

- Synthetic data via GENERATOR — numbers change on each deploy, never hardcode expected values
- CTV (Connected TV) has 0 clicks by design — verified queries handle NULLIF division
- `daily_budget_allocation` = campaign.budget / duration_days (denormalized into fact)
- All derived metrics (ROAS, CTR, CPM, CPC, CVR) live in the semantic view, not in SQL views
- Demo narrative leads with the *experience* (chat → answer → chart), not the plumbing

## Key Commands

```bash
# Deploy: paste deploy_all.sql into Snowsight, click Run All
# Teardown: paste teardown_all.sql into Snowsight, click Run All
# Demo: AI & ML > Agents > MEDIA_CAMPAIGN_AGENT > "Add to CoWork"
```
