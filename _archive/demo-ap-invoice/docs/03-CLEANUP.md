# Cleanup Guide

## Quick Teardown

1. Open **Snowsight**
2. Create a new SQL worksheet
3. Paste the entire contents of `teardown_all.sql`
4. Click **Run All**

## What Gets Removed

- Schema `SNOWFLAKE_EXAMPLE.AP_INVOICE` (CASCADE — all tables, views, stage, stream, task, procedures)
- Warehouse `SFE_AP_INVOICE_WH`
- Semantic view `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AP_INVOICE`
- Streamlit app `AP_INVOICE_DASHBOARD`

## What Is Preserved (Protected Infrastructure)

- `SNOWFLAKE_EXAMPLE` database
- `SNOWFLAKE_EXAMPLE.GIT_REPOS` schema
- `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS` schema
- `SFE_GIT_API_INTEGRATION`

These are shared across demo projects and must never be dropped.

## Manual Cleanup

If teardown fails or you need to remove objects individually:

```sql
USE ROLE SYSADMIN;
ALTER TASK IF EXISTS SNOWFLAKE_EXAMPLE.AP_INVOICE.VALIDATE_INVOICES_TASK SUSPEND;
DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.AP_INVOICE.AP_INVOICE_DASHBOARD;
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.AP_INVOICE CASCADE;
DROP WAREHOUSE IF EXISTS SFE_AP_INVOICE_WH;
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AP_INVOICE;
```
