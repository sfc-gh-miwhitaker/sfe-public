# Cleanup Guide

## Quick Cleanup

1. Open **Snowsight**
2. Create a **New SQL Worksheet**
3. Paste the entire contents of `teardown_all.sql`
4. Click **Run All**

## What Gets Removed

- Schema `SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY` and all objects within it (CASCADE)
- Warehouse `SFE_GLAZE_AND_CLASSIFY_WH`
- Compute pool `SFE_GLAZE_VISION_POOL`
- Semantic view `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_GLAZE_PRODUCTS`
- Git repository `SNOWFLAKE_EXAMPLE.TOOLS.SFE_GLAZE_AND_CLASSIFY_REPO`

## What Is Preserved

These shared resources are **never** dropped:

| Object | Reason |
|--------|--------|
| `SNOWFLAKE_EXAMPLE` database | Shared by all demos |
| `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS` schema | Shared semantic view container |
| `SNOWFLAKE_EXAMPLE.TOOLS` schema | Shared Git/tool infrastructure |
| `SFE_GIT_API_INTEGRATION` | Expensive to recreate, shared |

## Manual Cleanup (if teardown fails)

```sql
USE ROLE SYSADMIN;

-- Stop SPCS service first
ALTER SERVICE IF EXISTS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_VISION_SERVICE SUSPEND;
DROP SERVICE IF EXISTS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_VISION_SERVICE;
DROP COMPUTE POOL IF EXISTS SFE_GLAZE_VISION_POOL;

-- Then drop schema
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY CASCADE;
DROP WAREHOUSE IF EXISTS SFE_GLAZE_AND_CLASSIFY_WH;
```
