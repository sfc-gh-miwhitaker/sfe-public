# Operational Flow - Approach 3: Schema-on-Read

Author: SE Community
Last Updated: 2026-02-26
Expires: 2026-03-28
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview

Schema-on-Read keeps raw VARIANT data intact and creates views that flatten and type-cast on demand.
Every query re-evaluates the FLATTEN logic against the current raw data — zero ETL lag, full schema
evolution tolerance, but compute cost on every read. The simplest approach to deploy and the most
flexible when OpenAI's response schema changes.

## Operational Flow

```mermaid
flowchart TB
    subgraph sources ["OpenAI API Sources"]
        direction LR
        CHAT_API["Chat Completions API<br/><i>text, tool calls, structured output, refusals</i>"]
        BATCH_API["Batch API<br/><i>bulk classification results</i>"]
        USAGE_API["Usage API<br/><i>daily token consumption buckets</i>"]
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

    subgraph load ["COPY INTO with METADATA$FILENAME"]
        direction LR
        COPY1["COPY INTO<br/>RAW_CHAT_COMPLETIONS"]
        COPY2["COPY INTO<br/>RAW_BATCH_OUTPUTS"]
        COPY3["COPY INTO<br/>RAW_USAGE_BUCKETS"]
    end

    S1 -->|"openai_jsonl_ff"| COPY1
    S2 -->|"openai_jsonl_ff"| COPY2
    S3 -->|"openai_jsonl_ff"| COPY3

    subgraph bronze ["Bronze — Raw VARIANT Tables (the only persisted layer)"]
        RAW_CC["RAW_CHAT_COMPLETIONS<br/><i>loaded_at · source_file · raw VARIANT</i>"]
        RAW_BO["RAW_BATCH_OUTPUTS<br/><i>loaded_at · source_file · raw VARIANT</i>"]
        RAW_UB["RAW_USAGE_BUCKETS<br/><i>loaded_at · source_file · raw VARIANT</i>"]
    end

    COPY1 --> RAW_CC
    COPY2 --> RAW_BO
    COPY3 --> RAW_UB

    subgraph views ["Schema-on-Read Views — Computed at Query Time"]
        direction TB

        subgraph chat_views ["Chat Completion Views"]
            V_COMP["<b>V_COMPLETIONS</b><br/>LATERAL FLATTEN(raw:choices)<br/><i>One row per choice · dot-notation extraction<br/>content, refusal, finish_reason, token usage</i>"]
            V_TOOL["<b>V_TOOL_CALLS</b><br/>Double FLATTEN: choices → tool_calls<br/><i>TRY_PARSE_JSON on arguments string<br/>function name · parsed args VARIANT</i>"]
            V_STRUCT["<b>V_STRUCTURED_OUTPUTS</b><br/>WHERE TRY_PARSE_JSON(content) IS NOT NULL<br/><i>JSON content parsed to traversable VARIANT<br/>Excludes refusals</i>"]
        end

        subgraph batch_views ["Batch Views"]
            V_BATCH["<b>V_BATCH_RESULTS</b><br/>LATERAL FLATTEN(response:body:choices, OUTER⇒TRUE)<br/><i>SUCCESS vs ERROR routing<br/>Unwrapped response body + error metadata</i>"]
        end

        subgraph usage_views ["Usage Views"]
            V_USAGE["<b>V_TOKEN_USAGE</b><br/>LATERAL FLATTEN(raw:results)<br/><i>Unix timestamps → TIMESTAMP_NTZ<br/>model · project_id · api_key_id dimensions</i>"]
        end
    end

    RAW_CC -->|"LATERAL FLATTEN<br/>raw:choices"| V_COMP
    RAW_CC -->|"Double FLATTEN<br/>choices → tool_calls"| V_TOOL
    RAW_CC -->|"FLATTEN + filter<br/>TRY_PARSE_JSON ≠ NULL"| V_STRUCT
    RAW_BO -->|"FLATTEN OUTER ⇒ TRUE<br/>response:body:choices"| V_BATCH
    RAW_UB -->|"LATERAL FLATTEN<br/>raw:results"| V_USAGE

    subgraph consumers ["Consumers — Every Query Re-Evaluates Views"]
        direction LR
        SNOWSIGHT["Snowsight<br/>Worksheets"]
        STREAMLIT["Streamlit in Snowflake<br/><i>OPENAI_DATA_EXPLORER</i>"]
        BI["BI Tools"]
    end

    V_COMP --> SNOWSIGHT
    V_COMP --> STREAMLIT
    V_TOOL --> SNOWSIGHT
    V_STRUCT --> STREAMLIT
    V_BATCH --> BI
    V_USAGE --> BI

    style sources fill:#1a1a2e,color:#fff,stroke:#e94560
    style stage fill:#16213e,color:#fff,stroke:#0f3460
    style load fill:#0f3460,color:#fff,stroke:#533483
    style bronze fill:#1a1a2e,color:#fff,stroke:#e94560
    style views fill:#0d2137,color:#fff,stroke:#29B5E8
    style chat_views fill:#112d4e,color:#fff,stroke:#3f72af
    style batch_views fill:#112d4e,color:#fff,stroke:#3f72af
    style usage_views fill:#112d4e,color:#fff,stroke:#3f72af
    style consumers fill:#1b262c,color:#fff,stroke:#bbe1fa
```

## Query-Time Transformation Detail

```mermaid
flowchart LR
    subgraph raw_payload ["Raw VARIANT Payload"]
        direction TB
        R1["raw:choices[] — array of alternatives"]
        R2["raw:choices[].message.tool_calls[] — nested array"]
        R3["raw:choices[].message.content — string OR JSON string"]
        R4["raw:response:body:choices — batch wrapper"]
        R5["raw:results[] — usage bucket array"]
    end

    subgraph techniques ["Snowflake Techniques Applied"]
        direction TB
        T1["<b>Dot-Notation Traversal</b><br/>raw:usage:prompt_tokens_details:cached_tokens::NUMBER"]
        T2["<b>LATERAL FLATTEN</b><br/>Explode arrays into rows<br/>OUTER ⇒ TRUE preserves parent when array is NULL"]
        T3["<b>TRY_PARSE_JSON</b><br/>Safely parse JSON-as-string<br/>tool_call arguments · structured outputs"]
        T4["<b>IFF / CASE</b><br/>Polymorphic field handling<br/>content vs refusal vs tool_calls"]
        T5["<b>TO_TIMESTAMP(::NUMBER)</b><br/>Unix epoch → TIMESTAMP_NTZ"]
    end

    R1 -->|"LATERAL FLATTEN"| T2
    R2 -->|"Double FLATTEN"| T2
    R3 -->|"TRY_PARSE_JSON"| T3
    R4 -->|"FLATTEN OUTER"| T2
    R5 -->|"LATERAL FLATTEN"| T2

    style raw_payload fill:#1a1a2e,color:#fff,stroke:#e94560
    style techniques fill:#0d2137,color:#fff,stroke:#29B5E8
```

## Component Descriptions

| Object | Type | Source | Purpose |
|--------|------|--------|---------|
| `V_COMPLETIONS` | View | `RAW_CHAT_COMPLETIONS` | One row per choice — text content, refusals, token usage, model metadata |
| `V_TOOL_CALLS` | View | `RAW_CHAT_COMPLETIONS` | One row per tool invocation — function name, parsed JSON arguments |
| `V_STRUCTURED_OUTPUTS` | View | `RAW_CHAT_COMPLETIONS` | JSON content parsed to traversable VARIANT (excludes refusals) |
| `V_BATCH_RESULTS` | View | `RAW_BATCH_OUTPUTS` | Unwrapped batch responses — SUCCESS/ERROR split, content + error metadata |
| `V_TOKEN_USAGE` | View | `RAW_USAGE_BUCKETS` | Flattened usage buckets — time-series ready with model/project/key dimensions |

## Trade-offs

| Strength | Trade-off |
|----------|-----------|
| Zero ETL lag — always current | Warehouse compute on every read |
| Schema evolution tolerant — new fields appear automatically | Complex view definitions to maintain |
| No storage duplication — only raw data persisted | No pre-computed aggregations |
| Simplest to deploy and modify | Repeated FLATTEN cost for frequent queries |
| No refresh scheduling or warehouse dependency | Cannot serve as source for Cortex enrichment |
