---
name: demo-cortex-openai-enrichment
description: "Transform OpenAI API responses using Snowflake Cortex AI. Triggers: openai enrichment, schema on read, medallion dynamic tables, cortex classify, cortex sentiment, AI_COMPLETE structured output, PII detection, openai batch API, token usage analytics."
---

# AI-First Data Engineering: OpenAI + Snowflake Cortex

## Purpose

Three progressively sophisticated approaches to processing complex OpenAI API response JSON: Schema-on-Read views, Medallion Dynamic Tables, and Cortex AI enrichment (classification, sentiment, summarization, PII detection). Includes a Streamlit dashboard for comparing approaches.

## When to Use

- Adding new transformation approaches or enrichment patterns
- Extending the Streamlit dashboard
- Working with complex semi-structured API response data
- Comparing Schema-on-Read vs Dynamic Tables vs Cortex AI patterns

## Architecture

```
OpenAI API Responses (VARIANT)
  ├── RAW_CHAT_COMPLETIONS
  ├── RAW_BATCH_OUTPUTS
  └── RAW_USAGE_BUCKETS
       │
       ├── Approach 1: Schema-on-Read (Views)
       │   └── 5 views with LATERAL FLATTEN
       │
       ├── Approach 2: Medallion (Dynamic Tables)
       │   ├── Silver: 4 DTs (extraction + flatten)
       │   └── Gold: 3 DTs (aggregation + analytics)
       │
       └── Approach 3: Cortex AI Enrichment (Dynamic Tables)
           ├── DT_ENRICHED_COMPLETIONS (CLASSIFY_TEXT, SENTIMENT, SUMMARIZE)
           ├── DT_BATCH_ENRICHED (OpenAI vs Cortex QA comparison)
           └── DT_PII_SCAN (AI_COMPLETE for PII detection)
                │
                ▼
           Streamlit Explorer (4 tabs)
```

## Key Files

| File | Purpose |
|------|---------|
| `sql/02_tables/02_load_sample_data.sql` | GENERATOR + OBJECT_CONSTRUCT synthetic data |
| `sql/03_transformations/01_approach1_views.sql` | 5 Schema-on-Read views |
| `sql/03_transformations/02_approach2_dynamic_tables.sql` | Silver + Gold Dynamic Tables |
| `sql/03_transformations/03_approach3_cortex.sql` | Cortex enrichment DTs |
| `streamlit/app.py` | 4-tab comparison explorer |

## Three Approaches Compared

| Approach | Objects | Latency | Cost | Best For |
|----------|---------|---------|------|----------|
| Schema-on-Read | Views | Real-time | Zero compute | Ad-hoc exploration |
| Medallion DTs | Dynamic Tables | target_lag based | DT refresh credits | Production pipelines |
| Cortex AI | DTs + AI functions | target_lag based | DT + Cortex credits | AI-enriched analytics |

## Cortex Functions Used

| Function | Purpose | Location |
|----------|---------|----------|
| `CLASSIFY_TEXT` | Categorize completion content | `03_approach3_cortex.sql` |
| `SENTIMENT` | Sentiment scoring (-1 to 1) | `03_approach3_cortex.sql` |
| `SUMMARIZE` | Condense long completions | `03_approach3_cortex.sql` |
| `AI_COMPLETE` | Structured PII detection | `03_approach3_cortex.sql` |

## Extension Playbook: Adding a New Cortex Enrichment

1. Add a new column to an existing DT or create a new DT in `sql/03_transformations/03_approach3_cortex.sql`
2. Use the appropriate Cortex function:
   - Classification: `CLASSIFY_TEXT(col, ['cat1','cat2',...])`
   - Sentiment: `SENTIMENT(col)`
   - Summarization: `SUMMARIZE(col, num_sentences)`
   - Custom: `AI_COMPLETE('model', prompt)` with structured JSON output
3. Add a tab or chart in `streamlit/app.py` to visualize the new enrichment
4. If comparing OpenAI vs Cortex results, follow the `DT_BATCH_ENRICHED` pattern

## Extension Playbook: Adding a New RAW Source Table

1. Create the VARIANT table in `sql/02_tables/01_create_tables.sql`
2. Add synthetic data in `sql/02_tables/02_load_sample_data.sql` using `GENERATOR(ROWCOUNT => N)` + `OBJECT_CONSTRUCT`
3. Create a Schema-on-Read view (Approach 1) in `01_approach1_views.sql`
4. Create Silver + Gold DTs (Approach 2) in `02_approach2_dynamic_tables.sql`
5. Optionally add Cortex enrichment (Approach 3) in `03_approach3_cortex.sql`

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.OPENAI_DATA_ENG` |
| Warehouse | `SFE_OPENAI_DATA_ENG_WH` |
| RAW Tables | `RAW_CHAT_COMPLETIONS`, `RAW_BATCH_OUTPUTS`, `RAW_USAGE_BUCKETS` |
| Views | 5 Schema-on-Read views (V_ prefix) |
| Dynamic Tables | 4 Silver + 3 Gold + 3 Cortex DTs |
| Streamlit | In-schema app |

## Gotchas

- Sample data uses GENERATOR + OBJECT_CONSTRUCT -- no External Access needed
- External Access Integration for OpenAI is only needed for live API mode
- `deploy_all.sql` is monolithic (~1246 lines) -- use numbered SQL files for targeted changes
- Cortex enrichment DTs incur AI credits on every refresh
- PII detection uses AI_COMPLETE with structured JSON prompt, not a dedicated PII function
