![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--05--01-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# QuickBooks API Medallion Architecture Demo

> DEMONSTRATION PROJECT - EXPIRES: 2026-05-01
> This demo uses Snowflake features current as of March 2026.
> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

Pull accounting data from QuickBooks Online directly into Snowflake using native features -- no external ETL tools needed. Walks through every layer of the medallion pattern with Cortex AI enrichment and Data Metric Functions for continuous quality monitoring.

**Author:** SE Community
**Last Updated:** 2026-03-02 | **Expires:** 2026-05-01 | **Status:** ACTIVE

## Quick Start

**Deploy in Snowsight (no clone needed):**
Copy [`deploy_all.sql`](deploy_all.sql) into a Snowsight worksheet and click **Run All**.

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) demo-api-quickbooks-medallion
cd sfe-public/demo-api-quickbooks-medallion && cortex
```

## First Time Here?

**No QBO credentials?** No problem. Run with synthetic sample data:

```sql
-- 1. Create schema + warehouse
-- Run: sql/01_setup/01_create_schema.sql

-- 2. Create Bronze raw tables
-- Run: sql/02_bronze/02_raw_tables.sql

-- 3. Load sample data (includes intentional DQ issues)
-- Run: sql/02_bronze/04_sample_data.sql

-- 4. Create Silver + Gold + DQ
-- Run files in sql/03_silver/, sql/04_gold/, sql/05_data_quality/ in order

-- 5. Explore!
SELECT * FROM AR_AGING;
SELECT * FROM ENRICHED_INVOICE_NOTES;
SELECT * FROM DQ_EXPECTATION_SUMMARY;
```

**Have QBO credentials?** See [docs/02-API-SETUP.md](docs/02-API-SETUP.md) for OAuth 2.0 setup.

## Architecture

```
QuickBooks Online API
        │
        ▼ OAuth 2.0 + External Access Integration
┌─────────────────────────────────────────────────────┐
│  Bronze: RAW_ tables (VARIANT JSON)                 │
│    Python stored proc with pagination + CDC         │
├─────────────────────────────────────────────────────┤
│  Silver: Dynamic Tables (incremental refresh)       │
│    STG_ tables (JSON path extraction)               │
│    Cortex: AI_SENTIMENT, AI_CLASSIFY, AI_COMPLETE   │
├─────────────────────────────────────────────────────┤
│  Gold: Analytics Views + Cortex Dynamic Tables      │
│    AR_AGING, REVENUE_BY_MONTH, VENDOR_SPEND         │
│    CUSTOMER_CLASSIFICATION, PAYMENT_RISK            │
├─────────────────────────────────────────────────────┤
│  Data Quality: DMFs (serverless)                    │
│    System + Custom DMFs with Expectations           │
│    Anomaly Detection, Notifications, Remediation    │
└─────────────────────────────────────────────────────┘
```

See [diagrams/data-flow.md](diagrams/data-flow.md) for the full Mermaid architecture diagram.

## What You'll Learn

| Concept | Where |
|---------|-------|
| External Access Integration + OAuth 2.0 | `sql/02_bronze/01_network_and_auth.sql` |
| Python stored procedures with API calls | `sql/02_bronze/03_fetch_procedures.sql` |
| Dynamic tables with incremental refresh | `sql/03_silver/01_dynamic_tables.sql` |
| Cortex AI in dynamic tables | `sql/03_silver/02_cortex_enrichment.sql` |
| AI_COMPLETE structured outputs | `sql/03_silver/02_cortex_enrichment.sql` |
| AI_CLASSIFY with few-shot examples | `sql/04_gold/02_cortex_insights.sql` |
| System DMFs with expectations | `sql/05_data_quality/01_system_dmfs.sql` |
| Custom DMFs (FK, business rules) | `sql/05_data_quality/02_custom_dmfs.sql` |
| Anomaly detection (ML-powered) | `sql/05_data_quality/01_system_dmfs.sql` |
| DQ notifications (email + Slack) | `sql/05_data_quality/03_notifications.sql` |
| Remediation with SYSTEM$DATA_METRIC_SCAN | `sql/05_data_quality/04_quality_dashboard.sql` |
| Cortex Data Quality (Snowsight UI) | [docs/03-ARCHITECTURE.md](docs/03-ARCHITECTURE.md) |

## Project Structure

```
qbapi/
  README.md                              ← you are here
  deploy_all.sql                         ← single entry point
  teardown_all.sql                       ← complete cleanup
  diagrams/
    data-flow.md                         ← Mermaid architecture diagrams
  sql/
    01_setup/
      01_create_schema.sql               ← schema, warehouse, roles
    02_bronze/
      01_network_and_auth.sql            ← network rule, security integration, secret, EAI
      02_raw_tables.sql                  ← RAW_ tables (VARIANT + metadata)
      03_fetch_procedures.sql            ← Python stored proc for QBO API
      04_sample_data.sql                 ← synthetic JSON for offline demo
    03_silver/
      01_dynamic_tables.sql              ← JSON path extraction dynamic tables
      02_cortex_enrichment.sql           ← AI_SENTIMENT + AI_COMPLETE + AI_CLASSIFY
    04_gold/
      01_analytics_views.sql             ← AR aging, revenue, vendor spend, CLV
      02_cortex_insights.sql             ← AI customer classification, anomaly, risk
    05_data_quality/
      01_system_dmfs.sql                 ← system DMFs with expectations + anomaly detection
      02_custom_dmfs.sql                 ← FK integrity, positive amounts, date sequence
      03_notifications.sql               ← email + Slack webhook notifications
      04_quality_dashboard.sql           ← monitoring queries + remediation
    06_orchestration/
      01_tasks.sql                       ← hourly fetch task (live API mode only)
  docs/
    01-GETTING-STARTED.md                ← quick start guide
    02-API-SETUP.md                      ← QBO OAuth 2.0 setup
    03-ARCHITECTURE.md                   ← detailed architecture guide
```

## Sample Data Quality Issues

The sample data in `04_sample_data.sql` intentionally includes these issues so DMFs light up:

| Issue | Invoice | DMF That Catches It |
|-------|---------|-------------------|
| NULL customer_id | INV-007 | `NULL_COUNT` → `no_null_customers` |
| Duplicate invoice ID | INV-003 (twice) | `DUPLICATE_COUNT` → `no_duplicate_invoices` |
| Negative amount | INV-008 (-$500) | `DMF_POSITIVE_AMOUNT` → `all_positive_invoice_amounts` |
| Due date before txn date | INV-009 | `DMF_DATE_SEQUENCE` → `valid_invoice_date_sequence` |
| Orphan customer reference | INV-010 (customer 99) | `DMF_FK_CHECK` → `no_orphan_invoices` |

## Cleanup

```sql
-- Remove all demo objects
-- Run: teardown_all.sql
```

## Estimated Demo Costs

| Component | Size | Est. Credits/Hour |
|---|---|---|
| Warehouse | X-SMALL | 1 |
| Dynamic Table refresh | X-SMALL | <0.1 |
| Cortex AI enrichment | Per-row | ~0.01/row |
| DMFs (serverless) | Serverless | <0.1 |

**Total estimated cost:** <2 credits for full deployment + 1 hour of exploration.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| DMFs not firing | DMFs are serverless -- ensure `DATA_METRIC_SCHEDULE` is set on the table. |
| Dynamic tables stuck in FAILED | Check `SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())` for errors. |
| Cortex functions unavailable | Verify your region supports Cortex AI. See [Cortex availability](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions#availability). |

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skills (Cursor + Claude Code)
- **Cortex Code in Snowsight** -- Open this project in a Workspace for AI-assisted development
- **Cursor** -- Open locally with Cursor for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)

## Prerequisites

- Snowflake account with SYSADMIN + ACCOUNTADMIN roles
- Cortex AI functions enabled (most commercial regions)
- Data Metric Functions (GA)
- Optional: QuickBooks Online Developer account for live API mode
