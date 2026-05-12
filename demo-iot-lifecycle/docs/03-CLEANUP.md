# Cleanup Guide

## What Gets Removed

- Schema `IOT_LIFECYCLE` and all objects within (CASCADE)
- Warehouse `SFE_IOT_LIFECYCLE_WH`
- Semantic view `SV_IOT_FINANCIAL` from SEMANTIC_MODELS schema
- Agent removed from Snowflake Intelligence

## What Is Preserved

- `SNOWFLAKE_EXAMPLE` database
- `SNOWFLAKE_EXAMPLE.GIT_REPOS` schema
- `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS` schema
- `SFE_GIT_API_INTEGRATION`

## Steps

1. Copy `teardown_all.sql` into a Snowsight worksheet
2. Click **Run All**
