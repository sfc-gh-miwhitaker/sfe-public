# Snowpipe Streaming for IoT Guide

How to ingest IoT data -- GPS telemetry, RFID scans, sensor readings -- into Snowflake using Snowpipe Streaming (high-performance architecture, GA Sep 2025). Decision tree, REST API and SDK walk-throughs, table design, production best practices, costs, and migration from the classic SDK.

## Project Structure

- `README.md` -- Complete guide (12 parts + production readiness checklist). Part 2 (Choosing your ingestion path) is the centerpiece.
- `diagrams/` -- Standalone mermaid diagrams: ingestion decision tree, PIPE/channel architecture, exactly-once recovery flow, before/after IoT architecture.

## Content Principles

- High-performance architecture only (classic SDK is planned for deprecation -- do NOT recommend it)
- Decision tree first, walk-throughs second
- Every walk-through uses real, copy-pasteable code
- Honest about platform limits (4 MB REST request, 16 MB batch, 10 GB/s table cap, MAX_CLIENT_LAG defaults)
- Cross-links to companion `demo-iot-lifecycle` for hands-on context
- Mermaid diagrams in every part for visual learners

## When Helping with This Project

- This is a guide, not a demo -- no `deploy_all.sql`, no Snowflake objects to create
- All SQL and code snippets are embedded in `README.md`
- Snowpipe Streaming high-performance architecture is GA on AWS as of Sep 23, 2025
- Classic SDK (`snowflake-ingest-java`) is planned for deprecation -- do NOT recommend it for new work
- REST API is recommended for edge/lightweight devices (RFID scanners, GPS trackers, sensors)
- Multi-language SDKs (Python 3.9+, Node.js 20+, Java 11+) share a Rust core -- recommended for aggregator/gateway services
- Iceberg streaming requires SDK 3.0.0+ (default `MAX_CLIENT_LAG` = 30s for Iceberg, 1s for standard tables)
- Native objects for VARIANT/ARRAY columns (Python dict, JS Object, Java Map) -- NEVER serialized JSON strings
- `MATCH_BY_COLUMN_NAME = CASE_SENSITIVE` for cost optimization (you pay only for values, not JSON keys)
- Channels should be long-lived; deterministic naming convention (`source-env-region-id`)
- Exponential backoff on 429/500/503; on 409 reopen channel from last committed offset token
- Use `getChannelStatus` for monitoring (richer than `getLatestCommittedOffsetTokens`)
- ZSTD compression preferred over Gzip for REST API
- Track usage via `SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY` joined to `PIPES` (filter `service_type = 'SNOWPIPE_STREAMING'`)

## Related Projects

- [`demo-iot-lifecycle`](../demo-iot-lifecycle/) -- Companion demo: RFID garment lifecycle, fleet GPS, dual Cortex Agents. The simulator there uses INSERT for simplicity; this guide shows the production path.
- [`guide-external-access-playbook`](../guide-external-access-playbook/) -- Network rules, secrets, and external connectivity patterns.
- [`guide-data-quality-governance`](../guide-data-quality-governance/) -- Data quality monitoring (DMFs) for streamed data.
- [`tool-secrets-rotation-aws`](../tool-secrets-rotation-aws/) -- Key-pair and PAT rotation automation for streaming clients.
