---
name: tool-dr-cost-agent
description: "DR replication cost estimation agent with hybrid table awareness. Triggers: replication cost, DR cost, failover cost, replication pricing, business critical pricing, cross-region replication, replication estimate, dr cost agent."
---

# DR Cost Agent

## Purpose

Snowflake Intelligence agent for estimating cross-region DR/replication costs. Uses Business Critical pricing, auto-detects cloud/region, excludes hybrid tables from replication sizing, and provides conversational cost projections with built-in charting.

## When to Use

- Estimating DR replication costs for a customer
- Updating pricing data for new regions or cloud providers
- Extending the agent with new cost components or tools
- Adding verified queries to improve Cortex Analyst accuracy

## Architecture

```
ACCOUNT_USAGE views
    |
    v
Views (DB_METADATA_V2, HYBRID_TABLE_METADATA, REPLICATION_HISTORY)
    |
    v
PRICING_CURRENT table --> Semantic View (SV_DR_COST) --> Cortex Analyst
                                                              |
COST_PROJECTION SPROC (custom tool) -----------------> DR_COST_AGENT
                                                              |
                                                        data_to_chart
                                                              |
                                                         SI User
```

## Key Files

| File | Purpose |
|------|---------|
| `deploy.sql` | Single entry point (EXECUTE IMMEDIATE FROM monorepo) |
| `teardown.sql` | Full teardown including agent and semantic view |
| `sql/02_tables/01_pricing_current.sql` | Pricing table + 60-row seed (includes HYBRID_STORAGE) |
| `sql/03_views/01_db_metadata_v2.sql` | Hybrid-aware database sizing |
| `sql/04_procedures/01_cost_projection.sql` | Deterministic projection SPROC (agent custom tool) |
| `sql/05_semantic/01_semantic_view.sql` | SV_DR_COST semantic view |
| `sql/06_agent/01_agent.sql` | CREATE AGENT with tools, instructions, sample_questions |

## Extension Playbook: Adding a New Cost Component

1. Add service type rows to `sql/02_tables/01_pricing_current.sql` seed data
2. Add the component to the `COST_PROJECTION` SPROC in `sql/04_procedures/01_cost_projection.sql`
3. If the component has its own ACCOUNT_USAGE source, create a new view in `sql/03_views/`
4. Add the new view as a table in the semantic view (`sql/05_semantic/01_semantic_view.sql`)
5. Update agent instructions if the component needs special handling (`sql/06_agent/01_agent.sql`)

## Extension Playbook: Adding a New Region

1. Add pricing rows to `sql/02_tables/01_pricing_current.sql` for all five service types
2. The agent and semantic view handle new regions automatically (no code changes)

## Extension Playbook: Adding Verified Queries

1. Test the question in SI and capture the correct SQL
2. Add the verified query pair to the semantic view via ALTER SEMANTIC VIEW
3. Redeploy `sql/05_semantic/01_semantic_view.sql`

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.DR_COST_AGENT` |
| Warehouse | `SFE_TOOLS_WH` (shared) |
| Table | `PRICING_CURRENT` |
| Views | `DB_METADATA_V2`, `HYBRID_TABLE_METADATA`, `REPLICATION_HISTORY` |
| Procedure | `COST_PROJECTION` (custom tool) |
| Semantic View | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST` |
| Agent | `DR_COST_AGENT` |

## Gotchas

- ACCOUNTADMIN needed only for `GRANT DATABASE ROLE SNOWFLAKE.USAGE_VIEWER`; SYSADMIN for everything else
- Hybrid tables are silently SKIPPED during replication (BCR-1560-1582) -- the agent warns about this
- ACCOUNT_USAGE views lag up to 3 hours -- agent instructions note data freshness
- REPLICATION_HISTORY is empty if no replication groups exist -- agent handles this gracefully
- Pricing data is seeded at deploy time -- baseline estimates only
- Deploy uses monorepo Git repo (`SFE_DEMOS_REPO`), not a project-specific clone
- Agent uses `orchestration: auto` for model selection (never pin a specific model)
