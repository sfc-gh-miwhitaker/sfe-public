# Data Flow - OpenAI Data Engineering with Cortex AI

Author: SE Community
Last Updated: 2026-02-26
Expires: 2026-03-28
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview

Three approaches for transforming complex OpenAI API responses in Snowflake. All three share the
same Bronze layer (raw VARIANT tables loaded from staged JSONL files). Each approach offers
different trade-offs for latency, compute cost, and analytical capability.

## High-Level Architecture

```mermaid
flowchart TB
    subgraph sources ["OpenAI API Sources"]
        direction LR
        CHAT_API["Chat Completions API"]
        BATCH_API["Batch API"]
        USAGE_API["Usage API"]
    end

    subgraph bronze ["Bronze Layer — Raw VARIANT"]
        RAW_CC["RAW_CHAT_COMPLETIONS"]
        RAW_BO["RAW_BATCH_OUTPUTS"]
        RAW_UB["RAW_USAGE_BUCKETS"]
    end

    CHAT_API --> RAW_CC
    BATCH_API --> RAW_BO
    USAGE_API --> RAW_UB

    subgraph approach1 ["Approach 1: Cortex AI Enrichment ★"]
        DT_ENRICH["DT_ENRICHED_COMPLETIONS"]
        DT_BENRICH["DT_BATCH_ENRICHED"]
        DT_PII["DT_PII_SCAN"]
        V_DASH["V_ENRICHMENT_DASHBOARD"]
    end

    subgraph approach2_silver ["Approach 2 Silver: Dynamic Tables"]
        DT_COMP["DT_COMPLETIONS"]
        DT_TOOL["DT_TOOL_CALLS"]
        DT_BOUT["DT_BATCH_OUTCOMES"]
        DT_UFLAT["DT_USAGE_FLAT"]
    end

    subgraph approach2_gold ["Approach 2 Gold: Dynamic Tables"]
        DT_DAILY["DT_DAILY_TOKEN_SUMMARY"]
        DT_TCA["DT_TOOL_CALL_ANALYTICS"]
        DT_BSUM["DT_BATCH_SUMMARY"]
    end

    subgraph approach3 ["Approach 3: Schema-on-Read"]
        V_COMP["V_COMPLETIONS"]
        V_TOOL["V_TOOL_CALLS"]
        V_STRUCT["V_STRUCTURED_OUTPUTS"]
        V_BATCH["V_BATCH_RESULTS"]
        V_USAGE["V_TOKEN_USAGE"]
    end

    RAW_CC --> DT_COMP
    RAW_CC --> DT_TOOL
    RAW_BO --> DT_BOUT
    RAW_UB --> DT_UFLAT

    DT_UFLAT --> DT_DAILY
    DT_TOOL --> DT_TCA
    DT_BOUT --> DT_BSUM

    DT_COMP --> DT_ENRICH
    DT_BOUT --> DT_BENRICH
    DT_COMP --> DT_PII
    DT_TOOL --> DT_PII
    DT_ENRICH --> V_DASH

    RAW_CC --> V_COMP
    RAW_CC --> V_TOOL
    RAW_CC --> V_STRUCT
    RAW_BO --> V_BATCH
    RAW_UB --> V_USAGE

    style sources fill:#1a1a2e,color:#fff,stroke:#e94560
    style bronze fill:#1a1a2e,color:#fff,stroke:#e94560
    style approach1 fill:#0d2137,color:#fff,stroke:#29B5E8
    style approach2_silver fill:#16213e,color:#fff,stroke:#0f3460
    style approach2_gold fill:#0a1929,color:#fff,stroke:#f0a500
    style approach3 fill:#112d4e,color:#fff,stroke:#3f72af
```

## Detailed Operational Flow Diagrams

Each approach has a dedicated operational flow diagram with full component detail:

| Approach | Diagram | Highlights |
|----------|---------|------------|
| **1. Cortex AI Enrichment** | [approach1-cortex-enrichment.md](approach1-cortex-enrichment.md) | CLASSIFY_TEXT, SENTIMENT, SUMMARIZE, COMPLETE for PII |
| **2. Medallion Architecture** | [approach2-medallion.md](approach2-medallion.md) | Bronze → Silver → Gold with TARGET_LAG refresh chain |
| **3. Schema-on-Read** | [approach3-schema-on-read.md](approach3-schema-on-read.md) | LATERAL FLATTEN + Views, zero ETL lag |
