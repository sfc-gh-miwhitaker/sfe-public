# Ingestion Decision Tree

Author: SE Community
Last Updated: 2026-05-15
Expires: 2026-07-14
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview

How to choose between the Snowpipe Streaming REST API, language SDKs (Python, Node.js, Java), and the Snowflake Connector for Kafka based on the source of your IoT data.

## Diagram

```mermaid
flowchart TD
    Start{"Where does the\ndata originate?"}

    Start -->|"Constrained edge device\n(RFID, GPS, sensor)"| RESTAPI["REST API"]
    Start -->|"Python aggregator service"| Python["Python SDK"]
    Start -->|"Node.js / TypeScript hub"| Node["Node.js SDK"]
    Start -->|"Existing Kafka topic"| Kafka["Snowflake Connector\nfor Kafka"]
    Start -->|"High-throughput Java\n(over 1 GB/s)"| Java["Java SDK"]

    RESTAPI -->|"cURL or HTTP"| Pipe[(PIPE Object)]
    Python -->|"pip install snowpipe-streaming"| Pipe
    Node -->|"npm install snowpipe-streaming"| Pipe
    Kafka -->|"Partitions map to channels"| Pipe
    Java -->|"Maven dependency"| Pipe

    Pipe --> Tables["Tables\n(standard or Iceberg)"]
    Tables --> Query["Queryable in ~5 seconds"]
```

## Component Descriptions

| Path | Best For | Throughput Guidance |
|------|----------|---------------------|
| REST API | Edge devices that cannot run an SDK runtime | Up to ~1 MB/s per device |
| Python SDK | Aggregator/gateway services in Python | 10s of MB/s per process |
| Node.js SDK | IoT hubs, Lambda functions, TypeScript apps | 10s of MB/s per process |
| Java SDK | High-throughput aggregators, established Java estates | Up to 10 GB/s per table |
| Kafka Connector | Existing Kafka event bus (MQTT -> Kafka -> Snowflake) | Hundreds of MB/s aggregate |

## Change History
See `.claude/DIAGRAM_CHANGELOG.md` or project-specific changelog.
