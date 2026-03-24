# Cortex Cost Intelligence v4.0

**Natural-language cost governance for every Snowflake Cortex AI service.**

The semantic view is the product. Everything else is a presentation layer.

> **FinOps Journey (3 of 4):** This is the comprehensive Cortex cost platform. For REST API-specific billing (tokens, not credits), see [tool-cortex-rest-api-cost](../tool-cortex-rest-api-cost/). For query-level warehouse optimization, see [guide-cost-drivers](../guide-cost-drivers/). For generating REST API usage, see [guide-cortex-anthropic-redirect](../guide-cortex-anthropic-redirect/).

## What This Is

A complete cost intelligence platform for Snowflake Cortex AI services.
Covers **12 ACCOUNT_USAGE views** including the 5 new ones added in early 2026:

| Service | ACCOUNT_USAGE View | Status |
|---|---|---|
| Cortex Analyst | `CORTEX_ANALYST_USAGE_HISTORY` | GA |
| Cortex AI Functions | `CORTEX_AI_FUNCTIONS_USAGE_HISTORY` | **NEW** (GA Mar 2026) |
| Cortex Agent | `CORTEX_AGENT_USAGE_HISTORY` | **NEW** (Preview Feb 2026) |
| Snowflake Intelligence | `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` | **NEW** (Feb 2026) |
| Cortex Code CLI | `CORTEX_CODE_CLI_USAGE_HISTORY` | **NEW** (Feb 2026) |
| Provisioned Throughput | `CORTEX_PROVISIONED_THROUGHPUT_USAGE_HISTORY` | **NEW** (missed in v3) |
| Cortex Search | `CORTEX_SEARCH_DAILY_USAGE_HISTORY` | GA |
| Cortex Search Serving | `CORTEX_SEARCH_SERVING_USAGE_HISTORY` | GA |
| Cortex Functions (Legacy) | `CORTEX_FUNCTIONS_USAGE_HISTORY` | Legacy |
| Fine-Tuning | `CORTEX_FINE_TUNING_USAGE_HISTORY` | GA |
| Document Processing | `CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY` | GA |
| REST API | `CORTEX_REST_API_USAGE_HISTORY` | GA |

## Architecture

```
                    +-----------------------+
                    |   ACCOUNT_USAGE       |
                    |   (12 Cortex views)   |
                    +-----------+-----------+
                                |
                    +-----------v-----------+
                    |   Monitoring Views    |
                    |   (25+ views)         |
                    +-----------+-----------+
                                |
              +-----------------+------------------+
              |                 |                  |
    +---------v-------+ +------v------+ +---------v--------+
    | V_COST_INTEL_   | | Semantic    | | Governance       |
    | FLAT            | | View        | | Module           |
    | (BI tools)      | | (the API)   | | (budgets/alerts) |
    +---------+-------+ +------+------+ +---------+--------+
              |                |                   |
     +--------+    +-----------+-----------+       |
     |             |           |           |       |
  Tableau/    Cortex      Snowflake     MCP     Streamlit
  PowerBI/    Agent       Intelligence  (doc)   (optional)
  Sigma/Hex   (chat)      (built-in)
```

## Quick Start

### One-Click Deploy

```sql
-- Run the entire deployment script
-- (requires ACCOUNTADMIN)
USE ROLE ACCOUNTADMIN;

-- Option 1: Copy/paste deploy_all.sql into a Snowsight worksheet
-- Option 2: Git integration
EXECUTE IMMEDIATE FROM @your_git_repo/branches/main/tool-cortex-cost-intelligence/deploy_all.sql;
```

### What Gets Deployed

| Tier | What | Opt-in? |
|---|---|---|
| **1. Core** | 25+ monitoring views, flat view, snapshot table, config | Always |
| **2. Intelligence** | Semantic view + Cortex Agent | Always |
| **3. Governance** | Per-user budgets, spending alerts, runaway detection | Yes |
| **4. Dashboard** | 6-page Streamlit app | Yes |

## How to Use

### Ask Questions in Natural Language

Open **Snowflake Intelligence** and find the **Cortex Cost Intelligence** agent:

- "What was our total Cortex spend last month?"
- "Who are the top 5 spenders?"
- "What's the cheapest model for COMPLETE?"
- "Which service is growing fastest?"

### Connect Your BI Tool

Point Tableau, PowerBI, Sigma, or Hex at:

```
SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.V_COST_INTELLIGENCE_FLAT
```

Every row = one service event. Dimensions: date, service, user, model, function, role. Metrics: credits, cost_usd, operations, tokens. No joins needed.

### Governance

```sql
-- Enable per-user budgets
CALL PROC_GRANT_AI_ACCESS('ALICE', 500);
CALL PROC_GRANT_AI_ACCESS('BOB', 1000);

-- Check budget status
CALL PROC_CHECK_USER_BUDGETS();

-- Manually detect runaway queries
CALL PROC_MONITOR_AND_CANCEL_RUNAWAY_QUERIES(50);
```

## Key Views

| View | Purpose |
|---|---|
| `V_COST_INTELLIGENCE_FLAT` | **The BI interface.** Single denormalized view for any tool. |
| `V_CORTEX_DAILY_SUMMARY` | Daily aggregates by service type |
| `V_USER_SPEND_ATTRIBUTION` | Per-user, per-service, per-model spend |
| `V_MODEL_EFFICIENCY` | Cross-service model cost comparison |
| `V_COST_ANOMALIES_CURRENT` | Active week-over-week cost spikes |
| `V_CORTEX_COST_EXPORT` | Cross-reference with METERING_DAILY_HISTORY |
| `V_CORTEX_USAGE_HISTORY` | Snapshot-backed long-term trending |
| `SV_CORTEX_COST_INTELLIGENCE` | Semantic view for Cortex Analyst |

## Cleanup

```sql
-- Remove everything (run teardown_all.sql at the project root, or the nested version)
@teardown_all.sql
-- Alternate: @sql/99_cleanup/cleanup_all.sql
```

## Project Structure

```
tool-cortex-cost-intelligence/
  deploy_all.sql                    # Single-script deployment
  sql/
    01_setup/setup.sql              # Database, schema, config, snapshot table
    02_service_views/               # 12 service-specific detail views
    03_attribution/                 # User attribution + model efficiency
    04_summary/                     # Daily summary, anomalies, flat view
    05_governance/                  # Budgets, alerts, runaway detection
    06_forecast/                    # ML forecast support
    07_semantic/                    # Semantic view YAML + agent config
    99_cleanup/                     # Complete teardown
  streamlit/cortex_cost_intelligence/
    streamlit_app.py                # Multi-page navigation
    pages/                          # 6 pages
    utils/                          # Shared data, charts, formatting
  docs/
    05-MCP_INTEGRATION.md           # MCP integration path
```

## What Changed from v3.3

- **Renamed**: Cortex Cost Calculator → Cortex Cost Intelligence
- **Architecture**: Streamlit-centric → Agent-first, semantic view IS the product
- **Coverage**: 8 ACCOUNT_USAGE views → 12 (added Agent, AI Functions, Intelligence, Code CLI, Provisioned Throughput)
- **Killed**: CSV upload, POC-to-prod multipliers, fake benchmarks, monolithic app
- **Added**: `V_COST_INTELLIGENCE_FLAT` for BI tools, governance module, MCP docs
- **Modular SQL**: One monolithic file → 15+ focused SQL files
