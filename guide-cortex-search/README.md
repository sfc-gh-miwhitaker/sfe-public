# Cortex Search Automation Guide

This guide provides **automation patterns not found in official documentation**. For syntax reference, see the [official docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview).

## What This Guide Provides

| Resource | Unique Value |
|----------|--------------|
| [automation_patterns.sql](automation_patterns.sql) | Spec export/recreation, parameterized deployment templates |
| [cortex_search_e2e_test.sql](cortex_search_e2e_test.sql) | Runnable E2E test with sample data |
| [deployment_guide.md](deployment_guide.md) | CI/CD pipelines, GitHub Actions, Git Repository integration |
| [python_sdk_examples.py](python_sdk_examples.py) | Production Python patterns (REST API, not SEARCH_PREVIEW) |
| [agent_integration.sql](agent_integration.sql) | Use Cortex Search as a Cortex Agent tool |

## Deployment Workflow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   DEV/TEST  │────▶│   EXPORT    │────▶│    PROD     │
│   Account   │     │    SPEC     │     │   Account   │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   │                   │
      ▼                   ▼                   ▼
  Create via         DESCRIBE +          Deploy via
  Snowsight UI       generate SQL        CLI/CI-CD
```

## Quick Links

| Task | Resource |
|------|----------|
| Create a service | [CREATE CORTEX SEARCH SERVICE](https://docs.snowflake.com/en/sql-reference/sql/create-cortex-search) |
| Query (SQL testing) | [SEARCH_PREVIEW Function](https://docs.snowflake.com/en/sql-reference/functions/search_preview-snowflake-cortex) |
| Query (production) | [REST API](https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/cortex-search/cortex-search-introduction) / [Python SDK](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/query-cortex-search-service) |
| Filter syntax | [Query Service docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/query-cortex-search-service#filter-syntax) |
| Use in Cortex Agent | [agent_integration.sql](agent_integration.sql) |

## Run the E2E Test

```sql
-- Uses SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.COMPANY_EVENT_TRANSCRIPT_ATTRIBUTES
-- Execute sections sequentially in cortex_search_e2e_test.sql
```

## Export → Redeploy Pattern

```sql
-- 1. Export spec from test environment
DESCRIBE CORTEX SEARCH SERVICE my_db.my_schema.my_search;

-- 2. Generate CREATE statement (see automation_patterns.sql for full example)

-- 3. Deploy to production with parameterized CLI
snow sql -f service.sql \
  -D database=PROD_DB \
  -D schema=PROD_SCHEMA \
  -D warehouse=PROD_WH \
  --connection prod
```
