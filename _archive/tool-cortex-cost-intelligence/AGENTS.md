# Cortex Cost Intelligence v4.0

Natural-language cost governance platform for every Snowflake Cortex AI service. The semantic view is the product -- everything else is a presentation layer.

## Project Structure

- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `sql/01_setup/` -- Database, schema, config table, REST API pricing, snapshot table
- `sql/02_service_views/` -- 12 service-specific detail views (one per ACCOUNT_USAGE source)
- `sql/03_attribution/` -- User spend attribution and model efficiency views
- `sql/04_summary/` -- Daily summary, anomalies, cost export, flat BI view, usage history
- `sql/05_governance/` -- Opt-in: per-user budgets, spending alerts, runaway detection
- `sql/06_forecast/` -- Cost forecast view
- `sql/07_semantic/` -- Semantic view YAML + Cortex Agent creation
- `sql/99_cleanup/cleanup_all.sql` -- Complete teardown
- `streamlit/cortex_cost_intelligence/` -- Optional 6-page Streamlit dashboard
- `docs/05-MCP_INTEGRATION.md` -- MCP integration path

## Snowflake Environment

- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `CORTEX_COST_INTELLIGENCE`
- Agent: `SNOWFLAKE_INTELLIGENCE.AGENTS.CORTEX_COST_INTELLIGENCE`
- Semantic View: `SV_CORTEX_COST_INTELLIGENCE`
- BI View: `V_COST_INTELLIGENCE_FLAT` (single denormalized fact view for any BI tool)
- Task: `TASK_DAILY_CORTEX_SNAPSHOT` (cron ~3am, XSMALL managed warehouse)

## Key Patterns

- 12 ACCOUNT_USAGE views unified into one flat view and one semantic model
- REST API pricing uses dollar-per-million-tokens (not credits) -- separate billing model
- `TOKENS_GRANULAR` is an OBJECT (access via `:"input"::NUMBER`, not array indexing)
- Semantic view created via `SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML`
- Agent created in `SNOWFLAKE_INTELLIGENCE.AGENTS` schema (Snowflake Intelligence)
- Four deployment tiers: Core (always), Intelligence (always), Governance (opt-in), Streamlit (opt-in)
- Governance module adds: `CORTEX_USER_BUDGETS` table, budget check/restore tasks, runaway detection task, monthly spend alert
- `deploy_all.sql` deploys Tiers 1-2 inline; Tiers 3-4 require running modular SQL separately

## Development Standards

- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: `COMMENT = 'TOOL: ... (Expires: YYYY-MM-DD)'` on all objects
- COMMENT placement: VIEW before AS, TABLE after columns, SCHEMA after name
- Naming: SFE_ prefix for account-level objects only; project objects scoped by schema
- Views: Each service view follows the same column contract (date, service, user, model, function, role, credits, cost_usd, operations, tokens)

## When Helping with This Project

- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- `teardown_all.sql` at project root for cleanup (also available at `sql/99_cleanup/cleanup_all.sql`)
- Agent references warehouse `COMPUTE_WH` which is NOT created by this project
- Governance module objects are only created by running `sql/05_governance/` scripts separately
- Streamlit app is deployed separately (no CREATE STREAMLIT in `deploy_all.sql`)
- New ACCOUNT_USAGE views (Agent, AI Functions, Intelligence, Code CLI, Provisioned Throughput) added in early 2026
- `CORTEX_USAGE_CONFIG` table controls lookback days, anomaly thresholds, and feature flags

## Helping New Users

If the user seems confused or asks basic questions:

1. **Explain the concept** -- this tool lets you ask cost questions in natural language through Snowflake Intelligence
2. **Check deployment** -- ask if they've run `deploy_all.sql` in Snowsight yet
3. **Guide to first use** -- after deployment, open Snowflake Intelligence and find the Cortex Cost Intelligence agent
4. **Suggest starter questions** -- "What was our total Cortex spend last month?", "Who are the top 5 spenders?", "Which service is growing fastest?"
5. **BI users** -- point them at `V_COST_INTELLIGENCE_FLAT` (no joins needed)
6. **Governance** -- if they want budgets/alerts, walk them through running the `sql/05_governance/` scripts

## Related Projects

- [`tool-cortex-rest-api-cost`](../tool-cortex-rest-api-cost/) -- Focused dashboard for REST API token-based billing (narrower scope, deeper on one billing surface)
- [`tool-dr-cost-agent`](../tool-dr-cost-agent/) -- DR replication cost estimation agent (different cost domain)
- [`guide-cost-drivers`](../guide-cost-drivers/) -- Query-level cost diagnosis notebook (warehouse/query optimization, not Cortex-specific)
- [`guide-cortex-anthropic-redirect`](../guide-cortex-anthropic-redirect/) -- Generates REST API usage that this tool monitors
