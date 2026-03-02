# Operational Flow - Approach 2: Medallion Architecture

Author: SE Community
Last Updated: 2026-02-26
Expires: 2026-03-28
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview

Declarative Bronze → Silver → Gold pipeline using Dynamic Tables with automatic incremental refresh.
No orchestrator required — Snowflake handles dependency resolution and refresh scheduling via
TARGET_LAG. Silver tables extract and type-cast from raw VARIANT; Gold tables aggregate for
analytics. This layer also serves as the foundation for Approach 1 (Cortex AI Enrichment).

## Operational Flow

```mermaid
flowchart TB
    subgraph sources ["OpenAI API Sources"]
        direction LR
        CHAT_API["Chat Completions API"]
        BATCH_API["Batch API"]
        USAGE_API["Usage API"]
    end

    subgraph stage ["Internal Stage: @openai_raw_stage"]
        direction LR
        S1["chat_completions/*.json"]
        S2["batch_outputs/*.json"]
        S3["usage_buckets/*.json"]
    end

    CHAT_API -->|"JSONL export"| S1
    BATCH_API -->|"JSONL export"| S2
    USAGE_API -->|"JSONL export"| S3

    subgraph bronze ["Bronze — Raw VARIANT Tables"]
        direction LR
        RAW_CC["RAW_CHAT_COMPLETIONS<br/><i>loaded_at · source_file · raw VARIANT</i>"]
        RAW_BO["RAW_BATCH_OUTPUTS<br/><i>loaded_at · source_file · raw VARIANT</i>"]
        RAW_UB["RAW_USAGE_BUCKETS<br/><i>loaded_at · source_file · raw VARIANT</i>"]
    end

    S1 -->|"COPY INTO<br/>METADATA$FILENAME"| RAW_CC
    S2 -->|"COPY INTO<br/>METADATA$FILENAME"| RAW_BO
    S3 -->|"COPY INTO<br/>METADATA$FILENAME"| RAW_UB

    subgraph silver ["Silver — Typed Dynamic Tables (TARGET_LAG = 5 min)"]
        direction TB

        DT_COMP["<b>DT_COMPLETIONS</b><br/>LATERAL FLATTEN(raw:choices)<br/><i>completion_id · model · content · refusal<br/>is_refusal · has_tool_calls · is_structured_output<br/>content_length · cache_hit_ratio · reasoning_tokens</i>"]

        DT_TOOL["<b>DT_TOOL_CALLS</b><br/>Double FLATTEN: choices → tool_calls<br/><i>function_name · arguments_json<br/>TRY_PARSE_JSON → arguments_parsed<br/>argument_count via OBJECT_KEYS</i>"]

        DT_BOUT["<b>DT_BATCH_OUTCOMES</b><br/>FLATTEN OUTER ⇒ TRUE on response:body:choices<br/><i>outcome: SUCCESS / API_ERROR / REFUSAL / HTTP_ERROR<br/>content_parsed via TRY_PARSE_JSON<br/>error_code · error_message</i>"]

        DT_UFLAT["<b>DT_USAGE_FLAT</b><br/>LATERAL FLATTEN(raw:results)<br/><i>bucket_start/end → TIMESTAMP_NTZ<br/>bucket_date via DATE_TRUNC<br/>model · project_id · api_key_id · is_batch</i>"]
    end

    RAW_CC -->|"LATERAL FLATTEN<br/>+ dot-notation extraction<br/>+ type casting"| DT_COMP
    RAW_CC -->|"Double FLATTEN<br/>+ TRY_PARSE_JSON<br/>+ OBJECT_KEYS count"| DT_TOOL
    RAW_BO -->|"FLATTEN OUTER ⇒ TRUE<br/>+ CASE outcome routing<br/>+ TRY_PARSE_JSON"| DT_BOUT
    RAW_UB -->|"LATERAL FLATTEN<br/>+ TO_TIMESTAMP<br/>+ DATE_TRUNC"| DT_UFLAT

    subgraph gold ["Gold — Aggregated Dynamic Tables (TARGET_LAG = 5 min)"]
        direction TB

        DT_DAILY["<b>DT_DAILY_TOKEN_SUMMARY</b><br/>GROUP BY bucket_date, model, project_id, is_batch<br/><i>total_input/output/cached_tokens · total_requests<br/>est_input_cost_usd · est_output_cost_usd · est_total_cost_usd<br/>overall_cache_hit_ratio · avg_tokens_per_request</i>"]

        DT_TCA["<b>DT_TOOL_CALL_ANALYTICS</b><br/>GROUP BY function_name, model<br/><i>invocation_count · unique_completions<br/>avg_argument_count · avg_tokens_per_call<br/>first_seen · last_seen</i>"]

        DT_BSUM["<b>DT_BATCH_SUMMARY</b><br/>GROUP BY outcome, error_code, model<br/><i>record_count · pct_of_total<br/>total_tokens_used · avg_tokens_per_record</i>"]
    end

    DT_UFLAT -->|"SUM · ROUND<br/>cost estimation<br/>IFF(mini, low_rate, high_rate)"| DT_DAILY
    DT_TOOL -->|"COUNT · AVG<br/>MIN/MAX timestamps"| DT_TCA
    DT_BOUT -->|"COUNT · SUM<br/>window % via SUM() OVER()"| DT_BSUM

    subgraph cortex_dep ["Feeds Approach 1: Cortex Enrichment"]
        direction LR
        DT_ENRICH["DT_ENRICHED_COMPLETIONS"]
        DT_BENRICH["DT_BATCH_ENRICHED"]
        DT_PII["DT_PII_SCAN"]
    end

    DT_COMP -.->|"Cortex CLASSIFY_TEXT<br/>SENTIMENT · SUMMARIZE"| DT_ENRICH
    DT_BOUT -.->|"Cortex CLASSIFY_TEXT<br/>SENTIMENT"| DT_BENRICH
    DT_COMP -.->|"Cortex COMPLETE"| DT_PII
    DT_TOOL -.->|"Cortex COMPLETE"| DT_PII

    subgraph consumers ["Consumers"]
        direction LR
        SIS["Streamlit in Snowflake<br/><i>Silver & Gold table browser</i>"]
        SNOWSIGHT["Snowsight Worksheets"]
        BI["BI Tools"]
    end

    DT_DAILY --> SIS
    DT_TCA --> SIS
    DT_BSUM --> SIS
    DT_COMP --> SNOWSIGHT
    DT_DAILY --> BI

    style sources fill:#1a1a2e,color:#fff,stroke:#e94560
    style stage fill:#16213e,color:#fff,stroke:#0f3460
    style bronze fill:#1a1a2e,color:#fff,stroke:#e94560
    style silver fill:#0d2137,color:#fff,stroke:#29B5E8
    style gold fill:#0a1929,color:#fff,stroke:#f0a500
    style cortex_dep fill:#1b1b2f,color:#fff,stroke:#533483,stroke-dasharray: 5 5
    style consumers fill:#1b262c,color:#fff,stroke:#bbe1fa
```

## Refresh Dependency Chain

```mermaid
flowchart LR
    subgraph refresh ["Dynamic Table Refresh Order (automatic)"]
        direction LR
        RAW["Bronze<br/><i>RAW_* tables<br/>updated by COPY INTO</i>"]
        SIL["Silver<br/><i>DT_COMPLETIONS<br/>DT_TOOL_CALLS<br/>DT_BATCH_OUTCOMES<br/>DT_USAGE_FLAT</i><br/>TARGET_LAG = 5 min"]
        GOLD["Gold<br/><i>DT_DAILY_TOKEN_SUMMARY<br/>DT_TOOL_CALL_ANALYTICS<br/>DT_BATCH_SUMMARY</i><br/>TARGET_LAG = 5 min"]
        CRTX["Cortex (Approach 1)<br/><i>DT_ENRICHED_COMPLETIONS<br/>DT_BATCH_ENRICHED</i><br/>TARGET_LAG = 10 min<br/><i>DT_PII_SCAN</i><br/>TARGET_LAG = 30 min"]
    end

    RAW -->|"data change<br/>detected"| SIL
    SIL -->|"incremental<br/>refresh"| GOLD
    SIL -->|"incremental<br/>refresh"| CRTX

    style refresh fill:#0d2137,color:#fff,stroke:#29B5E8
```

## Component Descriptions

| Object | Layer | Source | TARGET_LAG | Purpose |
|--------|-------|--------|------------|---------|
| `DT_COMPLETIONS` | Silver | `RAW_CHAT_COMPLETIONS` | 5 min | Typed, flattened completions — content, refusal, tool call flags, cache ratio |
| `DT_TOOL_CALLS` | Silver | `RAW_CHAT_COMPLETIONS` | 5 min | One row per tool invocation — parsed arguments, argument count |
| `DT_BATCH_OUTCOMES` | Silver | `RAW_BATCH_OUTPUTS` | 5 min | Success/error/refusal routing — parsed content, error metadata |
| `DT_USAGE_FLAT` | Silver | `RAW_USAGE_BUCKETS` | 5 min | Flattened usage records — timestamps, model/project/key dimensions |
| `DT_DAILY_TOKEN_SUMMARY` | Gold | `DT_USAGE_FLAT` | 5 min | Daily cost estimation — input/output/cached tokens, USD estimates |
| `DT_TOOL_CALL_ANALYTICS` | Gold | `DT_TOOL_CALLS` | 5 min | Function frequency and argument patterns — invocation counts, avg tokens |
| `DT_BATCH_SUMMARY` | Gold | `DT_BATCH_OUTCOMES` | 5 min | Batch health — outcome distribution, error rates, token efficiency |

## Trade-offs

| Strength | Trade-off |
|----------|-----------|
| Pre-computed, fast reads | Additional storage for materialized data |
| Automatic refresh via TARGET_LAG | Warehouse must be available for refresh |
| Clear dependency chain — no orchestrator | Slight data latency (configurable per table) |
| Foundation for Cortex enrichment | Silver refresh must complete before Gold/Cortex |
