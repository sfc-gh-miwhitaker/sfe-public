# Before/After IoT Architecture

Author: SE Community
Last Updated: 2026-05-15
Expires: 2026-07-14
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview

How a typical IoT architecture transforms when adopting Snowpipe Streaming. The downstream pipeline -- Streams, Tasks, analytics views, semantic views, agents -- is unchanged. Only the ingestion layer changes.

## Diagram

```mermaid
flowchart TB
    subgraph before [Before: INSERT or File-Based]
        direction LR
        Devices1["IoT Devices"]
        Buffer1["Local Buffer\n(file or queue)"]
        ETL1["ETL Job\n(Python connector / file drop)"]
        Tables1[("GPS_TELEMETRY\nGARMENT_EVENTS")]
        Devices1 --> Buffer1 --> ETL1 --> Tables1
    end

    subgraph after [After: Snowpipe Streaming]
        direction LR
        Devices2["IoT Devices"]
        Path2{"Choose path"}
        REST2["REST API"]
        SDK2["SDK\n(Python / Node.js / Java)"]
        Pipe2["PIPE Object"]
        Tables2[("GPS_TELEMETRY\nGARMENT_EVENTS")]
        Devices2 --> Path2
        Path2 --> REST2 --> Pipe2
        Path2 --> SDK2 --> Pipe2
        Pipe2 --> Tables2
    end

    subgraph downstream [Downstream Pipeline - Unchanged]
        direction LR
        Streams["Streams + Tasks"]
        Views["Analytics Views"]
        Semantic["Semantic Views"]
        Agents["Cortex Agents"]
        Streams --> Views --> Semantic --> Agents
    end

    Tables1 --> Streams
    Tables2 --> Streams
```

## Component Descriptions

| Layer | Before | After |
|-------|--------|-------|
| Devices | Same | Same |
| Buffer | Local file or queue, application-managed | None -- rows go directly to Snowflake |
| Ingest | Polling INSERT or file-drop pipeline | Snowpipe Streaming (REST/SDK/Kafka) |
| Latency | Minutes (file landing) or polling cadence | ~5 seconds end-to-end |
| Exactly-once | Application-level dedup logic | Built-in via offset tokens |
| Cost model | Compute (warehouse + ETL) | Flat per-GB ingested |
| Downstream | Unchanged | Unchanged |

## Migration Pattern

The downstream pipeline does not need to change. Streams, Tasks, Dynamic Tables, analytics views, semantic views, and Cortex Agents all consume from base tables -- they don't care how rows arrived. This makes Snowpipe Streaming a **drop-in replacement for the ingestion layer** in most existing pipelines.

## Change History
See `.claude/DIAGRAM_CHANGELOG.md` or project-specific changelog.
