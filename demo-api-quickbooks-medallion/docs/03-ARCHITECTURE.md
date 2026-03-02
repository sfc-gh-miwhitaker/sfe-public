# Architecture Guide

## Medallion Overview

This demo implements a four-layer medallion architecture using Snowflake-native features:

```
QBO REST API → Bronze (RAW_) → Silver (STG_) → Gold (Analytics + AI)
                                    ↓
                           Data Quality (DMFs)
                                    ↓
                         Notifications + Remediation
```

## Layer Details

### Bronze: Raw Ingestion

**Objects**: `RAW_CUSTOMER`, `RAW_VENDOR`, `RAW_ITEM`, `RAW_ACCOUNT`, `RAW_INVOICE`, `RAW_PAYMENT`, `RAW_BILL`

- Full QBO JSON response stored as `VARIANT`
- `qbo_id` for deduplication, `fetched_at` for CDC ordering
- Python stored procedure (`FETCH_QBO_ENTITY`) handles OAuth, pagination, and CDC
- Uses External Access Integration for outbound HTTPS calls

**Key pattern**: Generic procedure handles all 7 entities -- same code, different entity name parameter.

### Silver: Dynamic Tables with Cortex AI

**Traditional extraction** (`01_dynamic_tables.sql`):
- `STG_CUSTOMER`, `STG_VENDOR`, `STG_ITEM`, `STG_ACCOUNT`, `STG_INVOICE`, `STG_INVOICE_LINE`, `STG_PAYMENT`, `STG_BILL`
- JSON path extraction (`raw_payload:Field::TYPE`)
- `QUALIFY ROW_NUMBER()` for deduplication
- `TARGET_LAG = '1 hour'`, `REFRESH_MODE = INCREMENTAL`

**Cortex enrichment** (`02_cortex_enrichment.sql`):
- `ENRICHED_INVOICE_NOTES` -- AI_SENTIMENT with custom categories (urgency, satisfaction, payment_intent)
- `CORTEX_PARSED_INVOICE` -- AI_COMPLETE structured output for schema-drift-resistant extraction
- `ENRICHED_CUSTOMER_PROFILE` -- AI_CLASSIFY for business size segmentation

**Key insight**: Cortex functions in dynamic tables with incremental refresh means AI only processes new rows. The entire pipeline is declarative -- no tasks, no orchestration code needed downstream of Bronze.

### Gold: Analytics + AI Insights

**Traditional views** (`01_analytics_views.sql`):
- `AR_AGING` -- Outstanding invoices in 0-30, 31-60, 61-90, 90+ day buckets
- `REVENUE_BY_MONTH` -- Monthly revenue trend
- `VENDOR_SPEND` -- Spend by vendor
- `CASH_FLOW_SUMMARY` -- Payments received vs bills due
- `CUSTOMER_LIFETIME_VALUE` -- Revenue, payment patterns, collection rate per customer

**Cortex dynamic tables** (`02_cortex_insights.sql`):
- `CUSTOMER_CLASSIFICATION` -- AI_CLASSIFY with few-shot examples for health categories
- `TRANSACTION_ANOMALIES` -- AI_COMPLETE structured output for anomaly reasoning
- `PAYMENT_RISK` -- AI_COMPLETE structured output for late payment risk scoring

### Data Quality: Full DMF Monitoring Stack

**System DMFs** (`01_system_dmfs.sql`):
- NULL_COUNT, DUPLICATE_COUNT on key columns with `EXPECTATION (VALUE = 0)`
- FRESHNESS with `ANOMALY_DETECTION = TRUE` (ML-powered)
- ROW_COUNT with both expectation and anomaly detection

**Custom DMFs** (`02_custom_dmfs.sql`):
- `DMF_FK_CHECK` -- Referential integrity between tables (multi-table argument)
- `DMF_POSITIVE_AMOUNT` -- Business rule: amounts must be positive
- `DMF_DATE_SEQUENCE` -- Business rule: due_date >= txn_date

**Notifications** (`03_notifications.sql`):
- Email integration (`SFE_DQ_EMAIL_INT`)
- Slack webhook integration (`SFE_DQ_SLACK_INT`)
- Database-level `DATA_QUALITY_MONITORING_SETTINGS`

**Dashboard & Remediation** (`04_quality_dashboard.sql`):
- Expectation violations via `DATA_QUALITY_MONITORING_EXPECTATION_STATUS`
- Anomaly status via `DATA_QUALITY_MONITORING_ANOMALY_DETECTION_STATUS`
- Historical results via `DATA_QUALITY_MONITORING_RESULTS`
- Row-level drill-down via `SYSTEM$DATA_METRIC_SCAN`
- On-demand testing via `SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS`

## Cortex Data Quality (Snowsight UI)

In addition to the SQL-based DQ setup, Snowflake offers AI-suggested quality checks through the Snowsight UI:

1. Navigate to **Catalog** > **Database Explorer**
2. Select `SNOWFLAKE_EXAMPLE` > `QB_API` > any Silver table
3. Click the **Data Quality** tab
4. Click **Get started** to see AI-suggested DMFs and expectations

Cortex Data Quality uses `AI_COMPLETE` to analyze table metadata and automatically suggest appropriate checks. This shows users both the **code-first** (SQL scripts in this demo) and **UI-first** (Snowsight Cortex Data Quality) approaches to data quality monitoring.

**Requirements for Cortex Data Quality**:
- `mistral-7b` and `llama3.1-8b` models must be allowed in the account
- Preview feature as of Feb 2026

## Orchestration Architecture

Only **one task** exists in this demo:

```
FETCH_QBO_ENTITIES_TASK (hourly cron)
    └── Calls FETCH_ALL_QBO_ENTITIES() stored procedure
        └── Inserts into RAW_ tables (Bronze)

Everything downstream is automatic:
    RAW_ tables change detected →
        STG_ dynamic tables refresh (TARGET_LAG = 1 hour) →
            Cortex enrichment refreshes (TARGET_LAG = DOWNSTREAM) →
                Gold dynamic tables refresh (TARGET_LAG = DOWNSTREAM)

    DMFs evaluate on their own cron schedule (hourly, serverless compute)
        → Results in SNOWFLAKE.LOCAL event table views
        → Notifications fire on violations/anomalies
```

## Cost Considerations

| Component | Compute | Notes |
|-----------|---------|-------|
| Bronze fetch | Warehouse (XS) | Hourly, typically < 1 min |
| Silver dynamic tables | Warehouse (XS) | Incremental refresh, processes only new rows |
| Cortex enrichment | Warehouse (XS) + Cortex credits | Incremental -- only new rows hit the LLM |
| Gold dynamic tables | Warehouse (XS) | Incremental cascade |
| DMFs | Serverless | No warehouse cost |
| Notifications | Free | Built into DQ monitoring |

**Tip**: For cost control, set `TARGET_LAG` to longer intervals (e.g., `'4 hours'`) or use `TRIGGER_ON_CHANGES` for DMF schedules in lower environments.
