# Deployment Guide

## Primary Deployment Method (Snowsight Run All)

1. Open `deploy_all.sql` and copy the entire script.
2. In Snowsight, create a new SQL worksheet.
3. Paste the script and click Run All.
4. Wait for completion (estimated 8-12 minutes on XSMALL warehouse).

## What Happens During Deployment

- Git integration is configured for the repository
- `SNOWFLAKE_EXAMPLE` is created (if it does not exist)
- `SNOWFLAKE_EXAMPLE.GIT_REPOS` is created (if it does not exist)
- A dedicated warehouse is created: `SFE_DATA_QUALITY_WH`
- Project schema and objects are created in `SNOWFLAKE_EXAMPLE.DATA_QUALITY`
- Streamlit app is deployed from the repository

## Post-Deployment Verification

Run the following checks:

```sql
SHOW TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.DATA_QUALITY;
SHOW STREAMS IN SCHEMA SNOWFLAKE_EXAMPLE.DATA_QUALITY;
SHOW TASKS IN SCHEMA SNOWFLAKE_EXAMPLE.DATA_QUALITY;
SHOW STREAMLITS;
```

If any objects are missing, re-run the relevant script from `sql/` or re-run `deploy_all.sql`.
