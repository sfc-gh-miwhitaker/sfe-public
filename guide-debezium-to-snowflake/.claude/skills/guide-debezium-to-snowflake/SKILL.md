---
name: guide-debezium-to-snowflake
description: >
  Guide for CDC pipelines using Debezium, Kafka, and Snowflake Kafka Connector v4.
  Triggers: debezium, kafka connector snowflake, cdc snowflake, openflow replacement,
  debezium postgresql snowflake, debezium mysql snowflake, debezium sql server snowflake,
  dynamic table cdc flattening, snowpipe streaming kafka.
---

# Guide: CDC from Operational Databases to Snowflake with Debezium

## Purpose

Reference guide for data engineers building log-based CDC pipelines into Snowflake using
only GA components: Debezium (source), Apache Kafka / Confluent Cloud (transport),
Snowflake Kafka Connector v4 with Snowpipe Streaming (sink), and Dynamic Tables
(flattening). Includes a factual forward reference to Snowflake Datastream (Private Preview).

## Architecture

```
Operational DB → Debezium (Kafka Connect source) → Kafka topics
  → Snowflake Kafka Connector v4 (SnowflakeStreamingSinkConnector)
  → cdc_raw.landing.<table>_raw (RECORD_CONTENT VARIANT)
  → Dynamic Table: cdc_raw.current_state.<table> (current-state, deduplicated)
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Complete guide: prerequisites, all connector configs, Dynamic Table patterns, ops |

## Snowflake Objects

| Object | Name | Purpose |
|--------|------|---------|
| Database | `cdc_raw` | Houses all CDC landing and current-state tables |
| Schema | `cdc_raw.landing` | Raw Kafka topic tables (VARIANT columns) |
| Schema | `cdc_raw.current_state` | Flattened, current-state Dynamic Tables |
| Warehouse | `kafka_ingest_wh` | XSMALL, used by connector + Dynamic Table refresh |
| Role | `kafka_ingest_role` | Least-privilege role for Kafka connector user |
| User | `kafka_ingest_user` | Key-pair auth; no password |

## Extension Playbook: Add a new source table

1. **Enable CDC on the source DB** — for Postgres, grant `SELECT` on the new table to the
   replication user; for SQL Server, run `sp_cdc_enable_table` for the new table.
2. **Update the Debezium connector** — add the new table to `table.include.list` and restart
   the connector. Debezium will snapshot the table and begin streaming changes.
3. **Update the Snowflake sink connector** — add the new Kafka topic to `topics` and a row
   to `snowflake.topic2table.map`. The connector creates the landing table automatically.
4. **Create a new Dynamic Table** in `cdc_raw.current_state` following the `QUALIFY
   ROW_NUMBER` pattern in the README. Cast columns from `record_content:after:<column>`.
5. **Verify** with `SELECT system$pipe_status(...)` on the landing table and
   `DYNAMIC_TABLE_REFRESH_HISTORY` on the new DT.

## Gotchas

- **v4 connector class changed**: Must use `SnowflakeStreamingSinkConnector`, not
  `SnowflakeSinkConnector`. The old class causes a class-not-found error.
- **v4 key-pair auth only**: OAuth is not supported in v4. Generate RSA keys with openssl,
  strip headers, remove newlines before pasting into config.
- **No Snowflake custom converters in v4**: Use `org.apache.kafka.connect.json.JsonConverter`,
  not `com.snowflake.kafka.connector.records.SnowflakeJsonConverter`.
- **Debezium envelope + schematization**: With `schematization=true` (v4 default), fields
  land as typed columns — but Debezium's `before`/`after`/`op`/`ts_ms` envelope structure
  means those are the column names, not the inner fields. Use `schematization=false` with
  VARIANT and cast in Dynamic Tables to avoid ambiguity.
- **Postgres WAL slot stalls**: A crashed Debezium connector holds the replication slot and
  prevents WAL cleanup. Monitor `pg_replication_slots.lag_bytes` and drop/recreate the slot
  if Debezium cannot reconnect.
- **Snapshot op vs. insert op**: Initial snapshot events use `op: "r"`, not `"c"`. The
  Dynamic Table pattern in this guide handles both correctly.
- **Dynamic Table minimum lag**: `TARGET_LAG` minimum is 60 seconds. Values below this fail
  at creation time.
- **Datastream is not a current path**: AWS-only, Private Preview, no Azure/GCP timeline as
  of August 2026. Do not design a production pipeline around it today.
