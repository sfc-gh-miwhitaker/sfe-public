![Guide](https://img.shields.io/badge/type-guide-blue)
![No Deploy](https://img.shields.io/badge/deploy-none-inactive)
![Expires](https://img.shields.io/badge/expires-2027--02--21-yellow)
![Status](https://img.shields.io/badge/status-ACTIVE-brightgreen)

# CDC from Operational Databases to Snowflake with Debezium

How to replicate row-level changes from PostgreSQL, MySQL, or SQL Server into Snowflake
using Debezium, Apache Kafka (or Confluent Cloud), the Snowflake Kafka Connector v4, and
Dynamic Tables — using only generally available, production-supported components.

**Audience:** Data engineers designing or migrating a CDC pipeline into Snowflake.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-08-21 | **Expires:** 2027-02-21 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Start Here

**Use this guide if:** you want log-based, low-impact CDC from an operational database into
Snowflake and you either already run Kafka or are open to Confluent Cloud as a managed
alternative.

**Consider a managed CDC tool instead (Fivetran, Airbyte, Estuary) if:** you have no Kafka
expertise on your team and want zero infrastructure to operate.

**Consider Snowflake OpenFlow if:** your source is SQL Server or PostgreSQL, your table count
is low, and you want a fully Snowflake-managed path without any external infrastructure.

Every component in this guide is **generally available**. Nothing here requires a preview
enrollment or a Snowflake support exception.

---

## Architecture

```
Operational DB (Postgres / MySQL / SQL Server)
        │
        │  reads WAL / binlog / CT logs
        ▼
┌─────────────────────────────────────┐
│  Debezium  (Kafka Connect source)   │  reads database transaction log
│  - one connector per source DB      │  emits change events to Kafka topics
│  - one Kafka topic per table        │
└──────────────────────┬──────────────┘
                       │  Kafka wire protocol
                       ▼
        ┌──────────────────────────┐
        │  Apache Kafka            │  message bus (self-managed or Confluent Cloud)
        │  (or Confluent Cloud)    │
        └──────────────┬───────────┘
                       │  Kafka Connect sink
                       ▼
┌──────────────────────────────────────────┐
│  Snowflake Kafka Connector v4            │  Snowpipe Streaming (sub-second latency)
│  - SnowflakeStreamingSinkConnector       │  lands events into Snowflake tables
│  - key-pair auth, community converters   │
└──────────────────────┬───────────────────┘
                       │  raw CDC events (VARIANT or schematized columns)
                       ▼
        ┌───────────────────────────────┐
        │  Snowflake landing table      │  one table per Kafka topic
        │  (RECORD_CONTENT VARIANT)     │  Debezium envelope preserved
        └───────────────┬───────────────┘
                        │  Dynamic Table refresh
                        ▼
        ┌───────────────────────────────┐
        │  Snowflake current-state DT   │  flattened, deduplicated, current rows
        │  (relational columns)         │  your BI / AI layer reads from here
        └───────────────────────────────┘
```

**Why this topology?** Debezium reads the database log with minimal source impact. Kafka
decouples the source from Snowflake so outages on either side don't cascade. Kafka Connector
v4 writes rows directly via Snowpipe Streaming — no file staging, no Snowpipe queues, no
separate pipes to manage. Dynamic Tables turn the raw event log into current-state relational
tables declaratively, without task scheduling.

---

## Prerequisites

### Source database setup

#### PostgreSQL
Enable logical replication:
```sql
-- postgresql.conf (requires restart)
wal_level = logical
max_replication_slots = 10   -- one per Debezium connector
max_wal_senders = 10

-- Create a replication user
CREATE USER debezium_user REPLICATION LOGIN PASSWORD '<YOUR_STRONG_PASSWORD>';
GRANT CONNECT ON DATABASE your_db TO debezium_user;
GRANT USAGE ON SCHEMA public TO debezium_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium_user;
```

#### MySQL / MariaDB
Enable binary logging:
```ini
# my.cnf
[mysqld]
server-id         = 1
log_bin           = mysql-bin
binlog_format     = ROW
binlog_row_image  = FULL
expire_logs_days  = 10
```
```sql
-- Create a CDC user
CREATE USER 'debezium'@'%' IDENTIFIED BY '<YOUR_STRONG_PASSWORD>';
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT
    ON *.* TO 'debezium'@'%';
FLUSH PRIVILEGES;
```

#### SQL Server
Enable CDC at the database and table level:
```sql
-- Enable CDC on the database (requires db_owner or sysadmin)
EXEC sys.sp_cdc_enable_db;

-- Enable CDC on each table you want to capture
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name   = N'orders',
    @role_name     = NULL;   -- NULL = no gating role

-- Create a dedicated SQL Server login for Debezium
CREATE LOGIN debezium WITH PASSWORD = '<YOUR_STRONG_PASSWORD>';
CREATE USER  debezium FOR LOGIN debezium;
GRANT SELECT ON SCHEMA::cdc TO debezium;
EXEC sp_addrolemember N'db_datareader', N'debezium';
```

### Kafka Connect worker
Any Kafka Connect 3.x distributed-mode cluster (Apache Kafka or Confluent). Download
the Debezium connector JARs from https://debezium.io/releases/ and the Snowflake Kafka
Connector v4 JAR from Confluent Hub or Maven Central. Place both in the Connect worker's
plugin path.

### Snowflake objects
```sql
USE ROLE securityadmin;

CREATE ROLE kafka_ingest_role;
CREATE USER kafka_ingest_user
    DEFAULT_ROLE = kafka_ingest_role;

-- Generate key pair and assign public key (see Step 2 for key gen commands)
ALTER USER kafka_ingest_user SET RSA_PUBLIC_KEY = '<your-public-key>';

USE ROLE sysadmin;
CREATE DATABASE IF NOT EXISTS cdc_raw;
CREATE SCHEMA  IF NOT EXISTS cdc_raw.landing;
CREATE SCHEMA  IF NOT EXISTS cdc_raw.current_state;
CREATE WAREHOUSE IF NOT EXISTS kafka_ingest_wh
    WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;

GRANT USAGE  ON DATABASE cdc_raw               TO ROLE kafka_ingest_role;
GRANT USAGE  ON SCHEMA   cdc_raw.landing       TO ROLE kafka_ingest_role;
GRANT CREATE TABLE ON SCHEMA cdc_raw.landing   TO ROLE kafka_ingest_role;
GRANT CREATE STAGE ON SCHEMA cdc_raw.landing   TO ROLE kafka_ingest_role;
GRANT USAGE  ON WAREHOUSE kafka_ingest_wh      TO ROLE kafka_ingest_role;

USE ROLE securityadmin;
GRANT ROLE kafka_ingest_role TO USER kafka_ingest_user;
```

---

## Step 1: Configure Debezium Source Connectors

Deploy each connector via the Kafka Connect REST API. Adjust `database.hostname`,
`database.dbname`/`database.server.name`, and include/exclude lists for your schema.

### PostgreSQL connector
```json
{
  "name": "postgres-source",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "tasks.max": "1",
    "database.hostname": "your-db-host",
    "database.port": "5432",
    "database.user": "debezium_user",
    "database.password": "<YOUR_DB_PASSWORD>",
    "database.dbname": "your_db",
    "topic.prefix": "pg",
    "schema.include.list": "public",
    "plugin.name": "pgoutput",
    "publication.autocreate.mode": "filtered",
    "slot.name": "debezium_slot",
    "heartbeat.interval.ms": "10000",
    "snapshot.mode": "initial"
  }
}
```

Topics created: `pg.<schema>.<table>` — e.g., `pg.public.orders`

### MySQL connector
```json
{
  "name": "mysql-source",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",
    "database.hostname": "your-db-host",
    "database.port": "3306",
    "database.user": "debezium",
    "database.password": "<YOUR_DB_PASSWORD>",
    "database.server.id": "184054",
    "topic.prefix": "mysql",
    "schema.history.internal.kafka.bootstrap.servers": "kafka:9092",
    "schema.history.internal.kafka.topic": "schema-changes.mysql",
    "database.include.list": "your_db",
    "snapshot.mode": "initial"
  }
}
```

Topics created: `mysql.<database>.<table>` — e.g., `mysql.your_db.orders`

### SQL Server connector
```json
{
  "name": "sqlserver-source",
  "config": {
    "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
    "tasks.max": "1",
    "database.hostname": "your-db-host",
    "database.port": "1433",
    "database.user": "debezium",
    "database.password": "<YOUR_DB_PASSWORD>",
    "database.names": "your_db",
    "topic.prefix": "mssql",
    "schema.history.internal.kafka.bootstrap.servers": "kafka:9092",
    "schema.history.internal.kafka.topic": "schema-changes.sqlserver",
    "table.include.list": "dbo.orders,dbo.customers",
    "snapshot.mode": "initial"
  }
}
```

Topics created: `mssql.<database>.<schema>.<table>` — e.g., `mssql.your_db.dbo.orders`

**Deploy:**
```bash
curl -X POST -H "Content-Type: application/json" \
  --data @postgres-source.json \
  http://localhost:8083/connectors
```

---

## Step 2: Configure Snowflake Kafka Connector v4

### Generate key pair for Snowflake authentication
```bash
# Generate private key
openssl genrsa -out rsa_key.pem 2048

# Generate public key
openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub

# Extract private key body (strip headers, remove newlines)
grep -v "BEGIN\|END" rsa_key.pem | tr -d '\n'
```

Assign the public key to the Snowflake user:
```sql
-- Copy the content of rsa_key.pub (strip the header/footer lines)
ALTER USER kafka_ingest_user SET RSA_PUBLIC_KEY = 'MIIBIjANBgkqh...';
```

### Sink connector configuration

> **Note:** v4 uses the `SnowflakeStreamingSinkConnector` class — not `SnowflakeSinkConnector`.
> Snowpipe Streaming is always used in v4; there is no `snowflake.ingestion.method` property.

```json
{
  "name": "snowflake-sink",
  "config": {
    "connector.class": "com.snowflake.kafka.connector.SnowflakeStreamingSinkConnector",
    "tasks.max": "4",

    "topics": "pg.public.orders,pg.public.customers",
    "snowflake.topic2table.map": "pg.public.orders:orders_raw,pg.public.customers:customers_raw",

    "snowflake.url.name": "<org>-<account>.snowflakecomputing.com",
    "snowflake.user.name": "kafka_ingest_user",
    "snowflake.private.key": "<private-key-without-headers>",
    "snowflake.database.name": "cdc_raw",
    "snowflake.schema.name": "landing",
    "snowflake.role.name": "kafka_ingest_role",

    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",

    "snowflake.enable.schematization": "false",

    "snowflake.validation": "client_side",
    "snowflake.compatibility.enable.autogenerated.table.name.sanitization": "true",
    "snowflake.compatibility.enable.column.identifier.normalization": "true",
    "snowflake.streaming.classic.offset.migration": "skip",
    "snowflake.streaming.validate.compatibility.with.classic": "false",

    "errors.tolerance": "NONE",
    "errors.log.enable": "true",
    "errors.deadletterqueue.topic.name": "dlq-snowflake-sink"
  }
}
```

**Why `schematization=false`?** Debezium wraps every event in a nested envelope
(`before`/`after`/`source`/`op`/`ts_ms`). Keeping schematization off lands the whole
envelope as a single `RECORD_CONTENT VARIANT` column — predictable regardless of schema
evolution in the source. You control flattening explicitly in the Dynamic Table layer.

### Landing table schema

The connector creates the landing table automatically. Its structure with schematization off:

```sql
-- Auto-created by the connector; shown here for reference
CREATE TABLE cdc_raw.landing.orders_raw (
    RECORD_CONTENT  VARIANT,  -- full Debezium CDC envelope
    RECORD_METADATA VARIANT   -- Kafka topic, partition, offset, timestamp
);
```

**Debezium envelope anatomy:**
```json
{
  "before": { "id": 1, "amount": 100.00, "status": "pending" },
  "after":  { "id": 1, "amount": 150.00, "status": "shipped" },
  "source": { "version": "...", "connector": "postgresql", "db": "...", "table": "orders" },
  "op":     "u",
  "ts_ms":  1753100000000
}
```

Operations: `c` = insert, `u` = update, `d` = delete, `r` = snapshot read.

---

## Step 3: Flatten CDC Events with Dynamic Tables

Two Dynamic Tables per source table: one raw → current-state transformation, optionally one
aggregated/enriched downstream layer.

### Pattern: current-state table (upsert + delete handling)

```sql
CREATE OR REPLACE DYNAMIC TABLE cdc_raw.current_state.orders
    TARGET_LAG    = '1 minute'
    WAREHOUSE     = kafka_ingest_wh
    REFRESH_MODE  = ADAPTIVE
AS
WITH ranked AS (
    SELECT
        -- Extract the "after" image for inserts/updates; "before" for deletes
        CASE
            WHEN record_content:op::STRING = 'd'
            THEN record_content:before
            ELSE record_content:after
        END                                         AS row_image,
        record_content:op::STRING                  AS cdc_op,
        record_content:ts_ms::TIMESTAMP_NTZ        AS source_ts,
        record_metadata:offset::INT                AS kafka_offset,
        record_metadata:partition::INT             AS kafka_partition,
        ROW_NUMBER() OVER (
            PARTITION BY
                CASE
                    WHEN record_content:op::STRING = 'd'
                    THEN record_content:before:id
                    ELSE record_content:after:id
                END
            ORDER BY record_metadata:offset DESC
        ) AS rn
    FROM cdc_raw.landing.orders_raw
    WHERE record_content:op::STRING IN ('c', 'u', 'd', 'r')
)
SELECT
    row_image:id::INT               AS order_id,
    row_image:customer_id::INT      AS customer_id,
    row_image:amount::DECIMAL(12,2) AS amount,
    row_image:status::STRING        AS status,
    cdc_op,
    source_ts
FROM ranked
WHERE rn = 1
  AND cdc_op <> 'd';    -- exclude deleted rows from the current-state view
```

> **Design note:** `ROW_NUMBER() OVER (PARTITION BY id ORDER BY kafka_offset DESC)` picks
> the latest event per primary key. This handles out-of-order event delivery and deduplicates
> retries. The `WHERE cdc_op <> 'd'` clause makes the Dynamic Table reflect current live rows
> only — deleted rows are simply absent.

### Intermediate tables: use `TARGET_LAG = DOWNSTREAM`

If you have enrichment tables downstream of the current-state table, set the current-state
table to `TARGET_LAG = DOWNSTREAM` and put the explicit lag on the leaf table:

```sql
-- Raw → current-state: refreshes when downstream needs it
CREATE OR REPLACE DYNAMIC TABLE cdc_raw.current_state.orders
    TARGET_LAG   = DOWNSTREAM
    WAREHOUSE    = kafka_ingest_wh
    REFRESH_MODE = ADAPTIVE
AS ...;

-- Leaf: drives the whole pipeline at 1-minute freshness
CREATE OR REPLACE DYNAMIC TABLE cdc_raw.current_state.orders_enriched
    TARGET_LAG   = '1 minute'
    WAREHOUSE    = kafka_ingest_wh
    REFRESH_MODE = ADAPTIVE
AS
SELECT o.*, c.name AS customer_name
FROM   cdc_raw.current_state.orders   o
JOIN   cdc_raw.current_state.customers c ON o.customer_id = c.customer_id;
```

### Handling schema evolution

When source columns are added, they appear in `RECORD_CONTENT:after` automatically. Cast
new columns in the Dynamic Table explicitly, or add a fallback:

```sql
-- Adding a new column to the DT without replacing (use ALTER DYNAMIC TABLE + REFRESH_MODE refresh)
-- Or simply recreate:
CREATE OR REPLACE DYNAMIC TABLE cdc_raw.current_state.orders ...
AS
SELECT
    ...,
    row_image:new_column::STRING AS new_column  -- add the new field
FROM ranked
WHERE rn = 1 AND cdc_op <> 'd';
```

`CREATE OR REPLACE` on a Dynamic Table triggers reinitialization of that table and its
downstream dependents. Schedule during a maintenance window or low-traffic period.

---

## Step 4: Operational Considerations

### Initial snapshot

Debezium performs a one-time snapshot of all existing rows before switching to streaming
log capture. During snapshot:
- Events use `op: "r"` (read), not `"c"` (insert).
- The snapshot of a large table can take minutes to hours — scale up your Kafka Connect
  workers for this phase if needed.
- Your Dynamic Table flattening query handles `"r"` events the same as `"c"` events.

### Schema registry (optional but recommended)

Without a schema registry, Debezium serializes events as JSON with embedded schemas.
With Confluent Schema Registry + Avro, you get:
- Smaller event payloads (schema stored once, not per-event)
- Schema evolution tracking with compatibility guarantees
- Better support for column type changes

To use Avro + schema registry, change the Kafka connector value converter:
```json
"value.converter": "io.confluent.connect.avro.AvroConverter",
"value.converter.schema.registry.url": "http://your-schema-registry:8081"
```

### Monitoring

**Kafka Connect health:**
```bash
# List running connectors and their status
curl http://localhost:8083/connectors?expand=status | jq '.[] | {name: .status.name, state: .status.connector.state}'

# Check task errors
curl http://localhost:8083/connectors/snowflake-sink/status | jq '.tasks'
```

**Snowflake ingestion lag:**
```sql
-- Check Snowpipe Streaming channel lag
SELECT system$pipe_status('cdc_raw.landing.orders_raw');

-- Check recent load history
SELECT file_name, status, row_count, last_load_time, error_count
FROM TABLE(information_schema.copy_history(
    table_name  => 'cdc_raw.landing.orders_raw',
    start_time  => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY last_load_time DESC;
```

**Dynamic Table freshness:**
```sql
-- Check whether DTs are meeting their target lag
SELECT name, target_lag, scheduling_state, last_completed_refresh,
       data_timestamp,
       DATEDIFF('second', data_timestamp, CURRENT_TIMESTAMP()) AS actual_lag_seconds
FROM   information_schema.dynamic_tables
WHERE  schema_name = 'CURRENT_STATE'
ORDER  BY actual_lag_seconds DESC;

-- Refresh history and failure reasons
SELECT name, state, error_message, refresh_start_time, refresh_end_time
FROM   TABLE(information_schema.dynamic_table_refresh_history())
WHERE  name = 'ORDERS'
  AND  refresh_start_time > DATEADD('hour', -6, CURRENT_TIMESTAMP())
ORDER  BY refresh_start_time DESC;
```

### Failure recovery

| Failure scenario | Recovery |
|-----------------|----------|
| Debezium connector crashes | Kafka Connect restarts it automatically; resumes from last committed offset |
| Kafka cluster outage | Debezium pauses; WAL/binlog accumulates on source DB until Kafka recovers — ensure source log retention is long enough |
| Snowflake connector pause | Kafka topics retain messages; connector resumes from last committed offset when restarted |
| Dynamic Table refresh failure | Snowflake retries; check `DYNAMIC_TABLE_REFRESH_HISTORY` for error details |

**Postgres WAL retention:** Set `wal_keep_size` or configure a replication slot's `wal_min_lsn`
to prevent the WAL from being vacuumed before Debezium can consume it during an outage.

```sql
-- Monitor WAL slot lag (run on PostgreSQL, not Snowflake)
SELECT slot_name, active, pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS lag_bytes
FROM   pg_replication_slots
WHERE  slot_name = 'debezium_slot';
```

### Dead-letter queue

The sink connector is configured with `errors.deadletterqueue.topic.name: dlq-snowflake-sink`.
Messages that fail to ingest land there with error headers. Inspect with:
```bash
kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic dlq-snowflake-sink \
  --property print.headers=true \
  --from-beginning
```

---

## Looking Ahead: Snowflake Datastream

Snowflake announced **Datastream** at Summit 2026 — a Kafka-wire-compatible managed streaming
service built natively into Snowflake. The key promise: **remove the Kafka broker from this
architecture entirely.**

With Datastream, the pipeline simplifies to:

```
Operational DB → Debezium → Snowflake Datastream → Snowflake table
```

Debezium continues to do what it does best — read the database transaction log. Datastream
replaces Kafka as the managed transport and landing layer: topics become governed Snowflake
objects, and a native pipe continuously materializes them into tables without a separate
Kafka Connect sink.

**Current status as of August 2026:** Private Preview, AWS-only. No committed GA date or
Azure/GCP timeline has been published. Do not plan a production deployment on Datastream
today if you are on Azure or GCP.

For the latest status and interest form: https://www.snowflake.com/en/product/features/datastream/

---

## Related Guides

- [Debezium connectors documentation](https://debezium.io/documentation/reference/stable/connectors/)
- [Snowflake Kafka Connector v4 documentation](https://docs.snowflake.com/en/connectors/kafkahp/about)
- [Snowflake Dynamic Tables documentation](https://docs.snowflake.com/en/user-guide/dynamic-tables/overview)
- [Kafka Connector v3 → v4 migration guide](https://docs.snowflake.com/en/user-guide/kafka-connector/migrate-v3-to-v4)
- [Debezium event flattening SMT reference](https://debezium.io/documentation/reference/stable/transformations/event-flattening.html)

---

## External References

- Snowflake Kafka Connector releases: https://docs.snowflake.com/en/connectors/kafka-connector-release-notes
- Debezium releases: https://debezium.io/releases/
- Snowflake Datastream product page: https://www.snowflake.com/en/product/features/datastream/
- Confluent Cloud managed Kafka: https://www.confluent.io/confluent-cloud/
