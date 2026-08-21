# guide-debezium-to-snowflake — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and the root sfe-public AGENTS.md.
     Do not duplicate them here. -->

## Architecture

```
Debezium (Kafka Connect source)
  → Kafka topics (one per source table)
  → Snowflake Kafka Connector v4 (SnowflakeStreamingSinkConnector)
  → cdc_raw.landing.<table>_raw  (RECORD_CONTENT VARIANT)
  → Dynamic Table: cdc_raw.current_state.<table>  (flattened, current-state)
```

## Conventions

- All SQL examples use `cdc_raw` database, `landing` / `current_state` schemas.
- Connector configs are JSON (Kafka Connect distributed mode format).
- Debezium topic prefix per source: `pg.*`, `mysql.*`, `mssql.*`.
- Dynamic Tables: `REFRESH_MODE = ADAPTIVE`, leaf tables carry explicit `TARGET_LAG`,
  intermediate tables use `TARGET_LAG = DOWNSTREAM`.

## Key Commands

```bash
# Deploy a Kafka Connect connector (distributed mode)
curl -X POST -H "Content-Type: application/json" \
  --data @<connector-config>.json \
  http://localhost:8083/connectors

# Check connector status
curl http://localhost:8083/connectors/<name>/status | jq

# Check Snowflake ingestion lag
snowsql -q "SELECT system\$pipe_status('cdc_raw.landing.orders_raw');"

# Monitor Dynamic Table freshness
snowsql -q "SELECT name, data_timestamp, DATEDIFF('second', data_timestamp, CURRENT_TIMESTAMP()) AS lag_s FROM information_schema.dynamic_tables WHERE schema_name='CURRENT_STATE';"
```
