# Operational Flow - Approach 1: Cortex AI Enrichment

Author: SE Community
Last Updated: 2026-02-26
Expires: 2026-03-28
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview

The headline feature. Snowflake Cortex functions classify, score sentiment, summarize, and scan
for PII in OpenAI outputs — analyzing AI with AI, entirely within Snowflake. No external API calls,
no data movement outside your account boundary. This approach depends on Approach 2's Silver
dynamic tables as its source.

## Operational Flow

```mermaid
flowchart TB
    subgraph sources ["OpenAI API Sources"]
        direction LR
        CHAT_API["Chat Completions API<br/><i>text, tool calls, structured output, refusals</i>"]
        BATCH_API["Batch API<br/><i>bulk classification results</i>"]
    end

    subgraph bronze ["Bronze — Raw VARIANT Tables"]
        direction LR
        RAW_CC["RAW_CHAT_COMPLETIONS<br/><i>loaded_at · source_file · raw VARIANT</i>"]
        RAW_BO["RAW_BATCH_OUTPUTS<br/><i>loaded_at · source_file · raw VARIANT</i>"]
    end

    CHAT_API -->|"COPY INTO"| RAW_CC
    BATCH_API -->|"COPY INTO"| RAW_BO

    subgraph silver ["Silver — Approach 2 Dynamic Tables (dependency)"]
        direction LR
        DT_COMP["DT_COMPLETIONS<br/><i>TARGET_LAG = 5 min</i><br/>typed, flattened completions"]
        DT_TOOL["DT_TOOL_CALLS<br/><i>TARGET_LAG = 5 min</i><br/>parsed function invocations"]
        DT_BOUT["DT_BATCH_OUTCOMES<br/><i>TARGET_LAG = 5 min</i><br/>success/error split"]
    end

    RAW_CC -->|"LATERAL FLATTEN<br/>raw:choices"| DT_COMP
    RAW_CC -->|"Double FLATTEN<br/>choices → tool_calls"| DT_TOOL
    RAW_BO -->|"FLATTEN OUTER ⇒ TRUE<br/>response:body:choices"| DT_BOUT

    subgraph cortex ["Approach 1: Cortex AI Enrichment Pipeline"]
        direction TB

        subgraph enrich ["DT_ENRICHED_COMPLETIONS — TARGET_LAG = 10 min"]
            direction LR
            E_CLASS["CLASSIFY_TEXT<br/><i>technical_explanation<br/>data_analysis<br/>code_generation<br/>summarization<br/>general_knowledge<br/>recommendation</i>"]
            E_SENT["SENTIMENT<br/><i>-1.0 → +1.0 score</i>"]
            E_SUMM["SUMMARIZE<br/><i>content > 200 chars</i>"]
        end

        subgraph batch_qa ["DT_BATCH_ENRICHED — TARGET_LAG = 10 min"]
            direction LR
            B_CLASS["CLASSIFY_TEXT<br/><i>billing · technical_support<br/>feature_request · account_access<br/>outage_report · compliance<br/>cancellation · data_request</i>"]
            B_SENT["SENTIMENT<br/><i>Cortex independent score</i>"]
            B_AGREE["Agreement Check<br/><i>OpenAI category vs<br/>Cortex category<br/>AGREE / DISAGREE</i>"]
        end

        subgraph pii ["DT_PII_SCAN — TARGET_LAG = 30 min"]
            direction LR
            P_SCAN["COMPLETE (claude-opus-4-6)<br/><i>Structured JSON prompt:<br/>has_pii · pii_types[]<br/>risk_level: none/low/medium/high</i>"]
            P_PARSE["TRY_PARSE_JSON<br/><i>Parsed PII analysis result</i>"]
        end
    end

    DT_COMP -->|"WHERE content IS NOT NULL<br/>AND is_refusal = FALSE"| enrich
    DT_BOUT -->|"WHERE outcome = 'SUCCESS'<br/>AND content_parsed IS NOT NULL"| batch_qa
    DT_COMP -->|"completion content"| pii
    DT_TOOL -->|"tool_call arguments"| pii

    B_CLASS --> B_AGREE
    P_SCAN --> P_PARSE

    subgraph dashboard ["V_ENRICHMENT_DASHBOARD — Aggregated View"]
        V_DASH["GROUP BY topic_classification<br/><i>response_count · avg_sentiment<br/>avg_topic_confidence · total_tokens<br/>tool_call_responses · structured_output_count</i>"]
    end

    enrich --> V_DASH

    subgraph consumers ["Consumers"]
        direction LR
        SIS["Streamlit in Snowflake<br/><i>OPENAI_DATA_EXPLORER</i>"]
        SNOWSIGHT["Snowsight Worksheets"]
    end

    V_DASH --> SIS
    enrich --> SIS
    batch_qa --> SIS
    pii --> SNOWSIGHT

    style sources fill:#1a1a2e,color:#fff,stroke:#e94560
    style bronze fill:#1a1a2e,color:#fff,stroke:#e94560
    style silver fill:#16213e,color:#fff,stroke:#0f3460
    style cortex fill:#0d2137,color:#fff,stroke:#29B5E8
    style enrich fill:#112d4e,color:#fff,stroke:#3f72af
    style batch_qa fill:#112d4e,color:#fff,stroke:#3f72af
    style pii fill:#112d4e,color:#fff,stroke:#3f72af
    style dashboard fill:#1b262c,color:#fff,stroke:#bbe1fa
    style consumers fill:#1b262c,color:#fff,stroke:#bbe1fa
```

## Cortex Functions Used

```mermaid
flowchart LR
    subgraph cortex_functions ["Snowflake Cortex Function Reference"]
        direction TB
        CF1["<b>CLASSIFY_TEXT(text, categories[])</b><br/>Returns {label, score} — zero-shot classification<br/>Used in: DT_ENRICHED_COMPLETIONS, DT_BATCH_ENRICHED"]
        CF2["<b>SENTIMENT(text)</b><br/>Returns FLOAT from -1.0 (negative) to +1.0 (positive)<br/>Used in: DT_ENRICHED_COMPLETIONS, DT_BATCH_ENRICHED"]
        CF3["<b>SUMMARIZE(text)</b><br/>Returns condensed text summary<br/>Used in: DT_ENRICHED_COMPLETIONS (content > 200 chars)"]
        CF4["<b>COMPLETE(model, prompt)</b><br/>Full LLM inference — structured JSON prompt for PII detection<br/>Used in: DT_PII_SCAN (claude-opus-4-6)"]
    end

    style cortex_functions fill:#0d2137,color:#fff,stroke:#29B5E8
```

## Component Descriptions

| Object | Type | Source | Cortex Functions | Purpose |
|--------|------|--------|-----------------|---------|
| `DT_ENRICHED_COMPLETIONS` | Dynamic Table (10 min lag) | `DT_COMPLETIONS` | CLASSIFY_TEXT, SENTIMENT, SUMMARIZE | Topic classification, sentiment scoring, content summarization |
| `DT_BATCH_ENRICHED` | Dynamic Table (10 min lag) | `DT_BATCH_OUTCOMES` | CLASSIFY_TEXT, SENTIMENT | QA OpenAI's classification against Cortex — agreement tracking |
| `DT_PII_SCAN` | Dynamic Table (30 min lag) | `DT_COMPLETIONS`, `DT_TOOL_CALLS` | COMPLETE (claude-opus-4-6) | PII detection with structured JSON analysis output |
| `V_ENRICHMENT_DASHBOARD` | View | `DT_ENRICHED_COMPLETIONS` | — | Aggregated metrics by topic for Streamlit dashboard |

## Trade-offs

| Strength | Trade-off |
|----------|-----------|
| Native AI — no external API calls | Cortex credit consumption per function call |
| QA one AI's output with another | Region/model availability for Cortex functions |
| PII detection built in | Latency per enrichment call (mitigated by TARGET_LAG) |
| Fully governed within Snowflake | Depends on Approach 2 Silver tables |
