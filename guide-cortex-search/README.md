# Cortex Search Service Guide

Resources for creating, managing, and deploying Snowflake Cortex Search services.

## Contents

| File | Description |
|------|-------------|
| [cortex-search-snowsight-guide.md](cortex-search-snowsight-guide.md) | Step-by-step guide for creating services via Snowsight UI |
| [cortex_search_examples.sql](cortex_search_examples.sql) | SQL reference with all commands and patterns |
| [cortex_search_e2e_test.sql](cortex_search_e2e_test.sql) | End-to-end test script using sample data |

## Quick Start

### 1. Create via Snowsight UI

1. Navigate to **AI & ML → Studio**
2. Click **+ Create** under Cortex Search Service
3. Select source table, search column, and attributes
4. Set target lag and create

### 2. Create via SQL

```sql
CREATE CORTEX SEARCH SERVICE my_db.my_schema.my_search
  ON text_column
  ATTRIBUTES category, region
  WAREHOUSE = my_wh
  TARGET_LAG = '1 hour'
AS (
  SELECT id, text_column, category, region
  FROM my_table
);
```

### 3. Query the Service

```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'my_db.my_schema.my_search',
    '{"query": "search term", "columns": ["text_column"], "limit": 5}'
  )
)['results'] AS results;
```

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Role | `SNOWFLAKE.CORTEX_USER` database role |
| Privileges | `CREATE CORTEX SEARCH SERVICE` on schema |
| Warehouse | Active warehouse for indexing |
| Source Data | Table/view with text column |

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

### Export Service Definition

```sql
DESCRIBE CORTEX SEARCH SERVICE my_db.my_schema.my_search;
```

## Filter Operators

| Operator | Example |
|----------|---------|
| `@eq` | `{"@eq": {"region": "US"}}` |
| `@contains` | `{"@contains": {"tags": "urgent"}}` |
| `@gte` / `@lte` | `{"@gte": {"date": "2024-01-01"}}` |
| `@and` / `@or` | `{"@and": [{"@eq": {...}}, {"@eq": {...}}]}` |
| `@not` | `{"@not": {"@eq": {"status": "closed"}}}` |

## Testing

Run the end-to-end test against sample data:

```sql
-- Uses SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.COMPANY_EVENT_TRANSCRIPT_ATTRIBUTES
-- Creates service in SNOWFLAKE_EXAMPLE.CORTEX_SEARCH

-- Execute sections sequentially in cortex_search_e2e_test.sql
```

## Resources

- [Cortex Search Overview](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview)
- [CREATE CORTEX SEARCH SERVICE](https://docs.snowflake.com/en/sql-reference/sql/create-cortex-search)
- [Query Cortex Search Service](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/query-cortex-search-service)
- [SEARCH_PREVIEW Function](https://docs.snowflake.com/en/sql-reference/functions/search_preview-snowflake-cortex)
