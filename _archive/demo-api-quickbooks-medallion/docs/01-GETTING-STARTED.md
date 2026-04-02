# Getting Started

## Prerequisites

- Snowflake account with **SYSADMIN** and **ACCOUNTADMIN** roles
- Snowflake Cortex AI functions enabled (most commercial regions)
- Data Metric Functions enabled (GA)

### Optional (for live API mode)

- QuickBooks Online Developer account ([developer.intuit.com](https://developer.intuit.com))
- OAuth 2.0 app credentials (Client ID + Client Secret)
- A QBO Sandbox company or production company Realm ID

## Quick Start (Sample Data Mode)

No QBO credentials needed. Uses synthetic data with intentional quality issues.

```sql
-- 1. Create schema, warehouse, roles
-- Run: sql/01_setup/01_create_schema.sql

-- 2. Create Bronze raw tables
-- Run: sql/02_bronze/02_raw_tables.sql

-- 3. Load sample data (includes intentional DQ issues)
-- Run: sql/02_bronze/04_sample_data.sql

-- 4. Create Silver dynamic tables (auto-refresh from Bronze)
-- Run: sql/03_silver/01_dynamic_tables.sql

-- 5. Create Cortex enrichment dynamic tables
-- Run: sql/03_silver/02_cortex_enrichment.sql

-- 6. Create Gold analytics views
-- Run: sql/04_gold/01_analytics_views.sql

-- 7. Create Gold Cortex insight dynamic tables
-- Run: sql/04_gold/02_cortex_insights.sql

-- 8. Attach Data Metric Functions
-- Run: sql/05_data_quality/01_system_dmfs.sql
-- Run: sql/05_data_quality/02_custom_dmfs.sql

-- 9. (Optional) Set up DQ notifications (requires ACCOUNTADMIN)
-- Run: sql/05_data_quality/03_notifications.sql

-- 10. Explore the DQ dashboard
-- Run: sql/05_data_quality/04_quality_dashboard.sql
```

## Quick Start (Live API Mode)

Uses real QuickBooks data via External Access Integration.

1. Follow [02-API-SETUP.md](02-API-SETUP.md) to configure OAuth 2.0
2. Run `sql/02_bronze/01_network_and_auth.sql` to create network rule, security integration, secret, and EAI
3. Complete the OAuth flow (see comments in the SQL file)
4. Run `sql/02_bronze/03_fetch_procedures.sql` to create the Python stored procedure
5. Run `sql/06_orchestration/01_tasks.sql` to create the scheduled task
6. Resume the task: `ALTER TASK FETCH_QBO_ENTITIES_TASK RESUME;`

## What to Explore

After deployment, try these queries:

```sql
-- AR aging report
SELECT * FROM AR_AGING ORDER BY days_past_due DESC;

-- Revenue by month
SELECT * FROM REVENUE_BY_MONTH;

-- Customer lifetime value
SELECT * FROM CUSTOMER_LIFETIME_VALUE;

-- Cortex: invoice note sentiment
SELECT * FROM ENRICHED_INVOICE_NOTES;

-- Cortex: customer health classification
SELECT * FROM CUSTOMER_CLASSIFICATION;

-- DQ: which expectations are failing?
SELECT * FROM DQ_EXPECTATION_SUMMARY;

-- DQ: drill into null customer IDs
SELECT * FROM TABLE(SYSTEM$DATA_METRIC_SCAN(
    REF_ENTITY_NAME => 'SNOWFLAKE_EXAMPLE.QB_API.STG_INVOICE',
    METRIC_NAME => 'SNOWFLAKE.CORE.NULL_COUNT',
    ARGUMENT_NAME => 'CUSTOMER_ID'
));
```

## Cleanup

```sql
-- Run teardown_all.sql to remove all demo objects
```
