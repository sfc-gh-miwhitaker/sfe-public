# Getting Started

## Prerequisites

- Snowflake account with SYSADMIN role access
- Cortex AI functions enabled in your region (for Approach 3 only)

## Deployment

1. Open `deploy_all.sql` in Snowsight
2. Click **Run All**
3. Verify the final statement returns "Deployment complete!"

## Exploring the Approaches

### Approach 1: Schema-on-Read

Query the views directly -- they flatten the raw VARIANT data on demand:

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG;

-- All completions with one row per choice
SELECT completion_id, model, finish_reason, content, total_tokens
FROM V_COMPLETIONS
ORDER BY created_at DESC;

-- Tool calls with parsed arguments
SELECT function_name, arguments_parsed
FROM V_TOOL_CALLS;

-- Structured JSON outputs (content that is valid JSON)
SELECT completion_id, content_parsed:sentiment::STRING AS sentiment
FROM V_STRUCTURED_OUTPUTS;
```

### Approach 2: Medallion Architecture

Dynamic tables auto-refresh from raw data. Query the Gold layer for analytics:

```sql
-- Daily token costs by model
SELECT bucket_date, model, total_requests, est_total_cost_usd
FROM DT_DAILY_TOKEN_SUMMARY
ORDER BY bucket_date;

-- Tool call frequency
SELECT function_name, invocation_count, avg_tokens_per_call
FROM DT_TOOL_CALL_ANALYTICS
ORDER BY invocation_count DESC;

-- Batch job health
SELECT outcome, record_count, pct_of_total
FROM DT_BATCH_SUMMARY;
```

### Approach 3: Cortex Enrichment

Deploy from `sql/03_transformations/03_approach3_cortex.sql`, then:

```sql
-- Topic classification with sentiment
SELECT completion_id, topic_classification, sentiment_score, content_summary
FROM DT_ENRICHED_COMPLETIONS;

-- OpenAI vs Cortex classification agreement
SELECT custom_id, openai_category, cortex_category, classification_agreement
FROM DT_BATCH_ENRICHED;
```

## Cleanup

Run `teardown_all.sql` in Snowsight to remove all demo objects.
