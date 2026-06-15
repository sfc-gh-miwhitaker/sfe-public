# Exactly-Once Recovery Flow

Author: SE Community
Last Updated: 2026-05-15
Expires: 2026-07-14
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview

How offset tokens enable exactly-once delivery for IoT streaming workloads. After a process crash, network blip, or 409 channel invalidation, the client reopens the channel and resumes from the last committed offset -- no duplicates, no gaps.

## Diagram

```mermaid
sequenceDiagram
    participant Client as IoT Client
    participant Channel as Channel
    participant Snowflake as Snowflake

    Note over Client,Snowflake: Steady-state ingestion
    Client->>Channel: openChannel("gps-V001")
    Channel-->>Client: last_committed_offset_token = 1042
    Client->>Channel: appendRow(row1043, offset=1043)
    Client->>Channel: appendRow(row1044, offset=1044)
    Channel->>Snowflake: commit batch
    Snowflake-->>Channel: committed offset = 1044

    Note over Client: Process crashes after row 1045 sent\nbut before commit confirmed

    Client-xChannel: appendRow(row1045, offset=1045)

    Note over Client,Snowflake: Recovery

    Client->>Channel: openChannel("gps-V001")
    Channel-->>Client: last_committed_offset_token = 1044

    Note over Client: Client knows 1044 was committed.\nResume from offset 1045.

    Client->>Channel: appendRow(row1045, offset=1045)
    Channel->>Snowflake: commit
    Snowflake-->>Channel: committed offset = 1045
```

## Component Descriptions

| Step | What Happens | Why It Matters |
|------|--------------|----------------|
| openChannel returns last committed offset | Snowflake tells client where it left off | Single source of truth for resume point |
| Client tracks offsets per row | Each appendRow has an offset_token | Lets Snowflake deduplicate replays |
| Server commits batches | Multiple rows commit atomically | Caller observes monotonic last_committed_offset_token |
| On reopen, resume from server offset | Discard any local offsets above server | Eliminates duplicate writes after crashes |

## Common Failure Patterns

| Failure | Status Code | Recovery |
|---------|-------------|----------|
| Channel invalidated (e.g., schema change, server restart) | 409 | Reopen channel; resume from `last_committed_offset_token` |
| Throttled | 429 | Exponential backoff, then retry same offset |
| Server error | 500/503 | Exponential backoff, then retry same offset |
| Stale continuation token | 4xx with code `STALE_CONTINUATION_TOKEN_SEQUENCER` | Reopen channel |

## Change History
See `.claude/DIAGRAM_CHANGELOG.md` or project-specific changelog.
