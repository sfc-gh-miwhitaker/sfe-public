# Deployment Guide

## Quick Start

1. Open **Snowsight** (the Snowflake web interface)
2. Create a new SQL worksheet
3. Paste the entire contents of `deploy_all.sql`
4. Click **Run All** (the play button with two arrows)
5. Wait ~2 minutes for all scripts to execute

## What Gets Created

The deploy script creates:

- **1 schema** (`AP_INVOICE`) with 6 tables, 5 views, 1 stage, 1 stream, 1 task, 4 stored procedures
- **1 warehouse** (`SFE_AP_INVOICE_WH`, XS, auto-suspend 60s)
- **1 semantic view** (`SV_AP_INVOICE` in `SEMANTIC_MODELS` schema)
- **1 Streamlit app** (`AP_INVOICE_DASHBOARD`)
- **27 sample invoices** with line items across 8 vendors and 3 properties

## Prerequisites

- **Role:** ACCOUNTADMIN (for API integration creation), then SYSADMIN (for all other objects)
- **Edition:** Enterprise or higher (required for AI functions and Cortex Analyst)
- **Region:** Must be in a region that supports AI_EXTRACT and AI_CLASSIFY (see [regional availability](https://docs.snowflake.com/en/sql-reference/functions/ai_extract#regional-availability))

## Post-Deployment

After deployment:

1. **Open the dashboard:** Find `AP_INVOICE_DASHBOARD` under Streamlit in Snowsight
2. **Optional - enable automated pipeline:** Run `ALTER TASK SNOWFLAKE_EXAMPLE.AP_INVOICE.VALIDATE_INVOICES_TASK RESUME;`
3. **Optional - process your own PDFs:** Upload PDF invoices to `@RAW_INVOICE_STAGE`, then call `SP_PROCESS_INVOICE('filename.pdf', 'Resort East')`

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Insufficient privileges" | Ensure you're using ACCOUNTADMIN for the first section, then SYSADMIN |
| "API integration not found" | The SFE_GIT_API_INTEGRATION creation may have failed — check ACCOUNTADMIN access |
| "Git repository fetch failed" | Check network connectivity to GitHub; may need to add the URL to allowed list |
| AI_EXTRACT returns errors | Verify your region supports AI_EXTRACT; check the file is < 100MB and < 125 pages |
| Streamlit app won't load | Run `ALTER STREAMLIT AP_INVOICE_DASHBOARD ADD LIVE VERSION FROM LAST;` |
