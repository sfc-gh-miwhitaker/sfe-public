---
name: demo-api-quickbooks-medallion
description: "QuickBooks Online API medallion architecture with Cortex AI enrichment and Data Metric Functions. Triggers: quickbooks, QBO, medallion architecture, bronze silver gold, external API integration, OAuth token refresh, data quality DMF, accounting data pipeline."
---

# QuickBooks API Medallion Architecture

## Purpose

Pull accounting data from QuickBooks Online into Snowflake using a medallion architecture (Bronze/Silver/Gold) with OAuth External Access Integration, Cortex AI enrichment, and Data Metric Functions for quality monitoring. Includes sample-data mode for demo without QBO credentials.

## When to Use

- Extending the API ingestion or adding new QBO entities
- Adding Silver-layer transformations or Gold-layer analytics
- Working with Data Metric Functions or quality alerting
- Adapting the OAuth External Access pattern for other APIs

## Architecture

```
QuickBooks Online API (OAuth 2.0)
       │
       ▼
Bronze: Python Stored Proc (External Access Integration)
  └── 7 RAW_ VARIANT tables (Customer, Vendor, Item, Account, Invoice, Payment, Bill)
       │
       ▼
Silver: Dynamic Tables (target_lag = '1 hour')
  └── 8 DTs with JSON extraction, QUALIFY dedup, LATERAL FLATTEN, Cortex enrichment
       │
       ▼
Gold: Analytics Views + Cortex Insights
  └── AR_AGING, REVENUE_BY_MONTH, CASH_FLOW_SUMMARY, CUSTOMER_CLASSIFICATION, TRANSACTION_ANOMALIES
       │
       ▼
Data Quality: System + Custom DMFs with Slack/Email notifications
```

## Key Files

| File | Purpose |
|------|---------|
| `sql/02_bronze/01_network_and_auth.sql` | OAuth 2.0 External Access Integration |
| `sql/02_bronze/03_fetch_procedures.sql` | Python stored proc with pagination and CDC watermark |
| `sql/02_bronze/04_sample_data.sql` | Synthetic data with intentional DQ issues |
| `sql/03_silver/01_dynamic_tables.sql` | 8 DTs: JSON extraction, dedup, flatten |
| `sql/03_silver/02_cortex_enrichment.sql` | AI_SENTIMENT, AI_COMPLETE, AI_CLASSIFY in DTs |
| `sql/04_gold/01_analytics_views.sql` | 5 business analytics views |
| `sql/04_gold/02_cortex_insights.sql` | AI-powered classification, anomaly, risk views |
| `sql/05_data_quality/01_system_dmfs.sql` | System DMFs with EXPECTATIONS |
| `sql/05_data_quality/02_custom_dmfs.sql` | Custom DMFs: FK check, positive amount, date sequence |
| `sql/05_data_quality/03_notifications.sql` | Email + Slack notification integrations |

## Two Usage Modes

| Mode | When | Auth Required |
|------|------|--------------|
| **Sample Data** | No QBO credentials, demo/learning | None |
| **Live API** | Real QBO tenant | OAuth client_id, client_secret, refresh_token |

Sample data includes intentional quality issues (NULLs, duplicates, negative amounts, orphan FKs) to exercise the DMF layer.

## Extension Playbook: Adding a New QBO Entity

1. Add a new `RAW_<ENTITY>` VARIANT table in `sql/02_bronze/02_raw_tables.sql`
2. Add an `INSERT INTO RAW_<ENTITY>` block in `sql/02_bronze/03_fetch_procedures.sql` (follow the pagination pattern)
3. Add sample data in `sql/02_bronze/04_sample_data.sql` with intentional DQ issues
4. Create a Silver Dynamic Table in `sql/03_silver/01_dynamic_tables.sql` with JSON path extraction and `QUALIFY ROW_NUMBER() OVER (...) = 1` dedup
5. Add system DMFs and expectations in `sql/05_data_quality/01_system_dmfs.sql`
6. Optionally add Cortex enrichment in `sql/03_silver/02_cortex_enrichment.sql`
7. Add Gold views if the entity supports business analytics

## Extension Playbook: Adding a Custom DMF

```sql
CREATE OR REPLACE DATA METRIC FUNCTION DMF_<CHECK_NAME>(ARG_T TABLE(...))
RETURNS NUMBER AS
'SELECT COUNT_IF(<condition>) FROM ARG_T';

ALTER TABLE <target> SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE <target> ADD DATA METRIC FUNCTION DMF_<CHECK_NAME> ON (<col>);
```

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.QB_API` |
| Warehouse | `SFE_QB_API_WH` |
| Bronze Tables | `RAW_CUSTOMER`, `RAW_VENDOR`, `RAW_ITEM`, `RAW_ACCOUNT`, `RAW_INVOICE`, `RAW_PAYMENT`, `RAW_BILL` |
| Silver DTs | 8 Dynamic Tables (target_lag = '1 hour') |
| Gold Views | `AR_AGING`, `REVENUE_BY_MONTH`, `VENDOR_SPEND`, `CASH_FLOW_SUMMARY`, `CUSTOMER_LIFETIME_VALUE` |
| Task | Hourly refresh orchestration |

## Gotchas

- OAuth tokens expire; the stored proc handles refresh via the secret object
- Sample data mode skips External Access Integration entirely
- Dynamic Tables are fully declarative -- the single task only handles Bronze ingestion
- DMFs with `TRIGGER_ON_CHANGES` fire on DML, not on DT refresh completion
- Custom DMFs must return NUMBER (count of violations)
- Gold Cortex views use AI_CLASSIFY/AI_COMPLETE -- cost-aware for large datasets
