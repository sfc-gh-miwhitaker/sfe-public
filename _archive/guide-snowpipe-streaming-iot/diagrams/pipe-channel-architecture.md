# PIPE and Channel Architecture

Author: SE Community
Last Updated: 2026-05-15
Expires: 2026-07-14
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview

How writers, channels, and the PIPE object compose to deliver ordered, exactly-once row ingestion into a Snowflake table. Every streaming write -- from REST API, SDK, or Kafka -- flows through this same shape.

## Diagram

```mermaid
flowchart LR
    subgraph writers [Writers]
        direction TB
        Writer1["GPS Device V-001"]
        Writer2["GPS Device V-002"]
        Writer3["RFID Aggregator"]
    end

    subgraph channels [Channels]
        direction TB
        C1["Channel:\ngps-prod-V001"]
        C2["Channel:\ngps-prod-V002"]
        C3["Channel:\nrfid-plant1-zoneA"]
    end

    subgraph pipe [PIPE Object]
        Validation["Schema validation"]
        Transforms["In-flight transforms\n(MATCH_BY_COLUMN_NAME)"]
        Cluster["Pre-clustering at ingest"]
        Validation --> Transforms --> Cluster
    end

    subgraph table [Target Table]
        Tbl[(GPS_TELEMETRY)]
    end

    Writer1 -->|"appendRow"| C1
    Writer2 -->|"appendRow"| C2
    Writer3 -->|"appendRow"| C3

    C1 --> pipe
    C2 --> pipe
    C3 --> pipe

    pipe --> Tbl
```

## Component Descriptions

| Component | Role | Notes |
|-----------|------|-------|
| Writer | Process producing rows (device, service, connector task) | One writer can manage many channels |
| Channel | Ordered, dedicated lane into a pipe | One per source partition; long-lived; deterministic naming |
| PIPE Object | Server-side processing layer | Auto-created as `<TABLE>-STREAMING`, or custom via `CREATE PIPE` |
| Target Table | Standard or Iceberg table | Schema evolution and clustering keys apply |

## Key Properties

- Rows within a single channel arrive **in order**
- Multiple channels can target the same pipe (and table)
- Each channel maintains its own offset token for exactly-once recovery
- A single client is bound to one pipe, but can manage thousands of channels

## Change History
See `.claude/DIAGRAM_CHANGELOG.md` or project-specific changelog.
