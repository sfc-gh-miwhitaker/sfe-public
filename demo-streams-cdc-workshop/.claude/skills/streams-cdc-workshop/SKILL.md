---
name: streams-cdc-workshop
description: "Project skill for the Snowflake Streams CDC workshop. Use when extending, testing, or troubleshooting RAW_ORDERS Streams, transactional CDC MERGE logic, triggered Tasks, retention, or staleness."
---

# Snowflake Streams CDC Workshop

Pair-programmed by SE Community + Cortex Code

## Purpose

Demonstrate full insert, update, and delete CDC with a Snowflake standard Stream,
transactional consumption, a triggered Task, and deterministic reconciliation.

## Architecture

```text
RAW_ORDERS -> RAW_ORDERS_STREAM -> SP_CONSUME_ORDER_CHANGES
                                      |-> CURRENT_ORDERS
                                      `-> ORDER_CHANGE_AUDIT
TASK_CONSUME_ORDER_CHANGES ------------^
```

The procedure inserts the stream snapshot into the audit table and reads the same
snapshot again for the MERGE. Both statements are in one transaction, so the offset
advances only when both writes commit.

## Key Files

| File | Role |
| ------ | ------ |
| `deploy_all.sql` | Creates a clean, synchronized workshop baseline |
| `sql/02_data/01_create_tables.sql` | Defines source, target, and audit tables |
| `sql/03_processing/01_create_stream.sql` | Creates the standard table Stream |
| `sql/03_processing/02_create_consumer.sql` | Defines transactional CDC consumption |
| `sql/03_processing/03_create_triggered_task.sql` | Defines optional event-driven execution |
| `sql/04_workshop/` | Ordered participant exercises |
| `sql/98_validation/01_smoke_tests.sql` | Returns behavioral PASS/FAIL evidence |
| `teardown_all.sql` | Removes only project-owned objects |

## Extension Playbook: Add Another CDC Source

1. Add a source, current-state target, and audit table in `sql/02_data/01_create_tables.sql`.
2. Seed and synchronize the source and target before creating the new Stream.
3. Create one standard Stream per independent consumer.
4. Add a dedicated consumer procedure that audits and merges one repeatable snapshot
   inside a single explicit transaction.
5. Filter standalone deletes with `METADATA$ACTION = 'DELETE'` and
   `NOT METADATA$ISUPDATE`; use INSERT rows for new and updated current state.
6. Add a separate triggered Task if event-driven processing is required.
7. Add deterministic mutations and exact reconciliation checks to the workshop and
   validation scripts.
8. Add every new SQL script to `deploy_all.sql` using its full Git stage path.

## Snowflake Objects

- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `STREAMS_CDC_WORKSHOP`
- Warehouse: `SFE_STREAMS_CDC_WH`
- Tables: `RAW_ORDERS`, `CURRENT_ORDERS`, `ORDER_CHANGE_AUDIT`
- Stream: `RAW_ORDERS_STREAM`
- Procedure: `SP_CONSUME_ORDER_CHANGES()`
- Task: `TASK_CONSUME_ORDER_CHANGES`

## Gotchas

- A plain SELECT does not advance a Stream; committed DML does.
- Updates appear as DELETE and INSERT rows with `METADATA$ISUPDATE = TRUE`.
- A Stream is a net-change offset, not an immutable event log.
- Audit and MERGE must share one transaction or they can observe different offsets.
- Do not use the update DELETE half as a standalone business delete.
- `CREATE OR REPLACE TABLE RAW_ORDERS` destroys history and stales its Stream.
- Process before `STALE_AFTER`; do not treat the retention extension as the SLA.
- The Task ships suspended and its owner needs the account-level `EXECUTE TASK` grant
  before it can run.
