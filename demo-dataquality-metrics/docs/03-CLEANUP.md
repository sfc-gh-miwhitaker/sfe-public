# Cleanup Guide

## Remove Demo Objects

Run the cleanup script from the repository stage:

```sql
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO/branches/main/sql/99_cleanup/teardown_all.sql;
```

## What Gets Removed

- Project schema `SNOWFLAKE_EXAMPLE.DATA_QUALITY`
- Streamlit app `DATA_QUALITY_DASHBOARD`
- Warehouse `SFE_DATA_QUALITY_WH`
- Git repository stage `SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DATA_QUALITY_REPO`

Shared infrastructure is preserved:

- Database `SNOWFLAKE_EXAMPLE`
- Schema `SNOWFLAKE_EXAMPLE.GIT_REPOS`
