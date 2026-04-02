# Cleanup Guide

## Quick Teardown

1. Open **Snowsight** and create a new SQL worksheet
2. Paste the contents of `teardown_all.sql`
3. Click **Run All**

## What Gets Removed

- `SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE` schema (all tables, views, procedures, dynamic tables, functions)
- `SFE_CAMPAIGN_ENGINE_WH` warehouse
- `SV_CAMPAIGN_ENGINE_ANALYTICS` semantic view
- `SFE_CAMPAIGN_ENGINE_REPO` Git repository object
- `CAMPAIGN_RESPONSE_MODEL` ML classification model
- `CAMPAIGN_ENGINE_DASHBOARD` Streamlit app
- `CAMPAIGN_ANALYTICS_AGENT` Cortex Intelligence agent

## What Is Preserved

These shared resources are **never dropped** by the teardown script:

| Object | Reason |
|---|---|
| `SNOWFLAKE_EXAMPLE` database | Shared by all demos |
| `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS` schema | Shared semantic views |
| `SNOWFLAKE_EXAMPLE.GIT_REPOS` schema | Shared Git repositories |
| `SFE_GIT_API_INTEGRATION` | Shared by all Git-based demos |

## Partial Cleanup

To remove only specific components:

```sql
-- Remove just the Streamlit app
DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.CAMPAIGN_ENGINE_DASHBOARD;

-- Remove just the ML model (to retrain)
DROP SNOWFLAKE.ML.CLASSIFICATION IF EXISTS SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.CAMPAIGN_RESPONSE_MODEL;

-- Remove just the agent
DROP CORTEX AGENT IF EXISTS SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.CAMPAIGN_ANALYTICS_AGENT;
```
