# Cleanup Guide

## Remove All Demo Objects

Run [`teardown_all.sql`](../teardown_all.sql) in a Snowsight SQL worksheet:

1. Open **Snowsight**
2. Create a new **SQL Worksheet**
3. Paste the contents of `teardown_all.sql`
4. Click **Run All**

This drops:
- `SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS` schema (and all objects within it)
- `SFE_GAMING_PLAYER_ANALYTICS_WH` warehouse
- `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_GAMING_PLAYER_ANALYTICS` semantic view

## What Is NOT Removed

The following shared infrastructure is protected and never dropped:

| Object | Why |
|--------|-----|
| `SNOWFLAKE_EXAMPLE` database | Shared by all demo projects |
| `SNOWFLAKE_EXAMPLE.GIT_REPOS` schema | Shared Git repository objects |
| `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS` schema | Shared semantic views |
| `SFE_GIT_API_INTEGRATION` | Shared Git API integration |

## Verify Cleanup

After running teardown, confirm:

```sql
SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;
-- GAMING_PLAYER_ANALYTICS should not appear

SHOW WAREHOUSES LIKE 'SFE_GAMING%';
-- Should return no results
```
