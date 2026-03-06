# DR Cost Agent (Snowflake Intelligence)

![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--05--01-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

> **DEMONSTRATION PROJECT** | **Last Updated:** 2026-03-04 | **Expires:** 2026-05-01
> This demo uses Snowflake features current as of March 2026.
> After expiration, validate against [Snowflake docs](https://docs.snowflake.com) before deploying.
> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

**Author:** SE Community
**Purpose:** Snowflake Intelligence agent for estimating DR/replication costs with hybrid table awareness
**Created:** 2025-12-08 | **Last Updated:** 2026-03-04 | **Expires:** 2026-05-01 (58 days) | **Status:** ACTIVE

## Quick Start

**Deploy in Snowsight (no clone needed):**

1. Copy [`deploy.sql`](deploy.sql) into a Snowsight worksheet and click **Run All**
2. Open **Snowflake Intelligence** and find **DR Cost Estimator**
3. Click a suggested prompt or ask your own question

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) tool-dr-cost-agent
cd sfe-public/tool-dr-cost-agent && cortex
```

## Brand New to GitHub or Cortex Code?

Start with the [Getting Started Guide](../guide-coco-setup/) -- it walks you through downloading the code and installing Cortex Code (the AI assistant that will help you with everything else).

## First Time Here?

**This is a 100% Snowflake-native tool. No local setup required!**

1. `deploy.sql` -- Deploy all objects in Snowsight (5 min)
2. Open Snowflake Intelligence -- find **DR Cost Estimator** agent
3. Click a suggested prompt to get started immediately
4. `teardown.sql` -- Remove everything when done

**Total setup time: ~5 minutes**

## What This Delivers

- **Snowflake Intelligence agent** for conversational DR cost estimation
- Hybrid-table-aware database sizing (hybrid tables are skipped during replication)
- Pre-loaded Business Critical pricing rates for AWS, Azure, and GCP regions (60 entries)
- Custom cost projection tool for deterministic calculations
- Backward-looking actual replication cost analysis (if replication is configured)
- Built-in charting for region comparisons and cost breakdowns
- Semantic view powering accurate SQL generation from natural language

## Conversation Starters

The agent shows these as clickable prompts when you first open it:

- **"Estimate DR costs to replicate my databases to a second region"**
- **"Which destination region is cheapest for DR?"**
- **"Do any of my databases have hybrid tables that won't replicate?"**
- **"What did replication actually cost last month?"**
- **"Compare costs if our daily change rate is 2% vs 10%"**

## Architecture

```
ACCOUNT_USAGE views (TABLE_STORAGE_METRICS, HYBRID_TABLES, REPLICATION_GROUP_USAGE_HISTORY)
       |
       v
Data Foundation (DB_METADATA_V2, HYBRID_TABLE_METADATA, REPLICATION_HISTORY)
       |
       v
PRICING_CURRENT table (AWS/Azure/GCP baseline rates)
       |
       v
Semantic View (SV_DR_COST) --> Cortex Analyst tool
       |                              |
       v                              v
COST_PROJECTION SPROC -------> DR_COST_AGENT (Snowflake Intelligence)
                                       |
                                       v
                                 Business User (natural language + charts)
```

## Important Notes

### Cost Disclaimer
**This tool provides estimates for budgeting purposes only.** Actual costs may vary based on data compression ratios, network conditions, change patterns, regional pricing, and contract terms. Pricing rates are baseline values. Always monitor actual consumption using Snowflake's ACCOUNT_USAGE views and consult with your account team for production planning.

### Hybrid Table Awareness
As of March 2026, hybrid table requests are cost-neutral (compute + storage only). However, **hybrid tables are silently skipped during replication refresh** (BCR-1560-1582). The agent proactively identifies databases with hybrid tables and adjusts cost projections to exclude them from replication transfer estimates.

### Technical Details
- **Objects**: All under `SNOWFLAKE_EXAMPLE.DR_COST_AGENT` schema
- **Warehouse**: `SFE_TOOLS_WH` (shared, XSmall, auto-suspend)
- **Agent**: `DR_COST_AGENT` in Snowflake Intelligence
- **Semantic View**: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST`
- **Security**: SYSADMIN owns objects, PUBLIC granted read access
- **Features**: Business Critical edition pricing, hybrid table awareness
- **Expiration**: Enforced in `deploy.sql`

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skill teaching the AI this project's patterns
- **Cortex Code in Snowsight** -- Open in a Workspace for AI-assisted development
- **Cursor** -- Open locally for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
