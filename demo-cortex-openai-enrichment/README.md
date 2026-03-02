# AI-First Data Engineering: OpenAI + Snowflake Cortex

![Expires](https://img.shields.io/badge/Expires-2026--03--28-orange)

> DEMONSTRATION PROJECT - EXPIRES: 2026-03-28
> This demo uses Snowflake features current as of February 2026.

Transform complex OpenAI API responses using Snowflake's native Cortex AI functions
for classification, sentiment analysis, and summarization - no external API calls required.

**Author:** SE Community
**Created:** 2026-02-26 | **Expires:** 2026-03-28 | **Status:** ACTIVE

## First Time Here?

1. **Deploy** - Copy `deploy_all.sql` into Snowsight, click "Run All"
2. **Explore** - Start with the Cortex AI enrichment tables, then explore views and dynamic tables
3. **Streamlit** - Upload `streamlit/app.py` as a Streamlit in Snowflake app
4. **Cleanup** - Run `teardown_all.sql` when done

## The Problem

OpenAI API responses are deeply nested JSON with variable schemas:

```
response
  ├── choices[]                    ← array of alternatives
  │   ├── message
  │   │   ├── content              ← string OR null
  │   │   ├── refusal              ← present only on policy violations
  │   │   └── tool_calls[]         ← optional array of function invocations
  │   │       └── function
  │   │           ├── name
  │   │           └── arguments    ← JSON string inside a JSON string
  │   └── finish_reason            ← stop | length | tool_calls | content_filter
  └── usage
      ├── prompt_tokens
      ├── completion_tokens
      └── prompt_tokens_details    ← nested sub-object with cached/audio tokens
          └── cached_tokens
```

This demo covers three data formats: **Chat Completions**, **Batch API output**, and **Usage API buckets**.

## Three Approaches

### Approach 1: Cortex AI Enrichment (The Headline Feature)

Use Snowflake Cortex to classify, score, summarize, and scan OpenAI outputs - 
analyzing AI with AI, entirely within Snowflake.

| Strength | Trade-off |
|----------|-----------|
| Native AI, no external APIs | Cortex credit consumption |
| QA one AI's output with another | Region/model availability |
| PII detection built-in | Latency per enrichment call |

**Objects:** `DT_ENRICHED_COMPLETIONS`, `DT_BATCH_ENRICHED`, `DT_PII_SCAN`, `V_ENRICHMENT_DASHBOARD`

### Approach 2: Medallion Architecture (Dynamic Tables)

Declarative Bronze-Silver-Gold pipeline with automatic incremental refresh.

| Strength | Trade-off |
|----------|-----------|
| Pre-computed, fast reads | Additional storage |
| Automatic refresh via TARGET_LAG | Warehouse must be available |
| Clear dependency chain | Slight data latency (configurable) |

**Silver:** `DT_COMPLETIONS`, `DT_TOOL_CALLS`, `DT_BATCH_OUTCOMES`, `DT_USAGE_FLAT`
**Gold:** `DT_DAILY_TOKEN_SUMMARY`, `DT_TOOL_CALL_ANALYTICS`, `DT_BATCH_SUMMARY`

### Approach 3: Schema-on-Read (FLATTEN + Views)

Keep raw VARIANT intact. Create views that flatten on demand.

| Strength | Trade-off |
|----------|-----------|
| Zero ETL lag | Query cost on every read |
| Schema evolution tolerant | Complex view definitions |
| No storage duplication | No pre-computed aggregations |

**Objects:** `V_COMPLETIONS`, `V_TOOL_CALLS`, `V_STRUCTURED_OUTPUTS`, `V_BATCH_RESULTS`, `V_TOKEN_USAGE`

## Cortex Credit Usage

The Cortex AI enrichment tables use Snowflake Cortex functions which consume credits:
- `CLASSIFY_TEXT` - Text classification
- `SENTIMENT` - Sentiment scoring
- `SUMMARIZE` - Content summarization
- `COMPLETE` - LLM inference for PII detection (uses `claude-opus-4-6` per customer request)

**Model Selection:** This demo uses `claude-opus-4-6` per customer request.
For cost/performance optimization, consider `llama3.1-70b` or `mistral-large2`.

For cost-conscious deployments, consider:
- Adding WHERE filters to limit processed rows
- Increasing TARGET_LAG to reduce refresh frequency
- Using the Silver dynamic tables without Cortex enrichment

## Key Techniques Demonstrated

- `SNOWFLAKE.CORTEX.CLASSIFY_TEXT`, `SENTIMENT`, `SUMMARIZE`, `COMPLETE` for AI enrichment
- `LATERAL FLATTEN` with `OUTER => TRUE` for optional arrays
- `TRY_PARSE_JSON` for safely parsing JSON-as-string (tool call arguments, structured outputs)
- Dot-notation traversal of deeply nested paths (`raw:choices[0].message.tool_calls`)
- Dynamic tables with `TARGET_LAG` for declarative pipelines
- `IFF` / `CASE` for polymorphic field handling (content vs refusal vs tool_calls)

## Project Structure

```
openai-data-engineering/
├── README.md
├── deploy_all.sql                            # Single-file deployment
├── teardown_all.sql                          # Complete cleanup
├── diagrams/
│   ├── data-flow.md                          # High-level architecture overview
│   ├── approach1-cortex-enrichment.md        # Approach 1 operational flow
│   ├── approach2-medallion.md                # Approach 2 operational flow
│   └── approach3-schema-on-read.md           # Approach 3 operational flow
├── sql/
│   ├── 01_setup/
│   │   └── 01_create_schema.sql
│   ├── 02_tables/
│   │   ├── 01_create_tables.sql
│   │   └── 02_load_sample_data.sql           # Full synthetic dataset
│   ├── 03_transformations/
│   │   ├── 01_approach1_views.sql            # FLATTEN + Views
│   │   ├── 02_approach2_dynamic_tables.sql   # Dynamic Table pipeline
│   │   └── 03_approach3_cortex.sql           # Cortex enrichment
│   └── 99_cleanup/
│       └── 01_drop_objects.sql
└── streamlit/
    └── app.py                                # Interactive explorer
```
