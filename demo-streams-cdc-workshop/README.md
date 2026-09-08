![Demo](https://img.shields.io/badge/type-demo-blue) ![SQL Workshop](https://img.shields.io/badge/workshop-SQL-29B5E8) ![Expires](https://img.shields.io/badge/expires-2026--10--08-yellow) ![Status](https://img.shields.io/badge/status-ACTIVE-green)

# Snowflake Streams CDC Workshop

A hands-on workshop for applying inserts, updates, and deletes from a Snowflake standard Stream into a current-state table while retaining durable audit evidence.

**Audience:** Data engineers and platform teams evaluating Snowflake-native procedural CDC.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-09-08 | **Expires:** 2026-10-08 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

1. Open Snowsight and create a SQL worksheet.
2. Paste the full contents of `deploy_all.sql` and select **Run All**.
3. Run `sql/04_workshop/01_first_change_batch.sql`.
4. Run `sql/98_validation/02_first_batch_pending_tests.sql`; all four checks should pass.
5. Continue through `sql/04_workshop/02_inspect_stream.sql` to `05_retention_and_staleness.sql`.
6. Optionally run scripts `06` and `07` to test the triggered Task.
7. Run `teardown_all.sql` when finished.

Deployment creates a synchronized four-row source and target. The Stream is empty, and the triggered Task is suspended.

## Learning Objectives

- Distinguish a Stream offset from an event queue or copied change table.
- Interpret `METADATA$ACTION`, `METADATA$ISUPDATE`, and `METADATA$ROW_ID`.
- Observe one update as a DELETE and INSERT pair.
- Prove that SELECT does not advance a Stream and committed DML does.
- Apply deletes and upserts while preserving an audit record in the same transaction.
- Reconcile current state exactly and inspect the `STALE_AFTER` deadline.
- Enable and verify an event-driven triggered Task without polling.

## Architecture

```text
Simulated order system
        |
        v
   RAW_ORDERS -----> RAW_ORDERS_STREAM -----> SP_CONSUME_ORDER_CHANGES
                                                   |          |
                                                   v          v
                                           CURRENT_ORDERS  ORDER_CHANGE_AUDIT
                                                   ^
                                                   |
                                     TASK_CONSUME_ORDER_CHANGES
```

The procedure writes the Stream snapshot to both targets inside one explicit transaction. If either write fails, the transaction rolls back and the Stream offset does not advance.

## Workshop Flow

| Step | Script | Expected evidence |
|------|--------|-------------------|
| 1 | `01_first_change_batch.sql` | One insert, one update, and one delete are committed to `RAW_ORDERS` |
| 2 | `02_inspect_stream.sql` | Four rows: standalone insert, update pair, standalone delete |
| 3 | `03_consume_and_reconcile.sql` | Four audit rows, exact source/target match, empty Stream |
| 4 | `04_second_change_batch.sql` | A three-row second delta is consumed without duplicates |
| 5 | `05_retention_and_staleness.sql` | Stream mode, stale state, `STALE_AFTER`, and retention parameters |
| 6 | `06_enable_triggered_task.sql` | Optional Task is resumed and a new order is inserted |
| 7 | `07_verify_and_stop_triggered_task.sql` | `TASK_HISTORY.SCHEDULED_FROM = 'TRIGGER'`; Task is suspended again |

Run `sql/98_validation/01_smoke_tests.sql` whenever the Stream is expected to be empty. Before the first consumption, run the dedicated pending-batch test instead.

## CDC Semantics

| Source operation | Stream rows | Consumer action |
|------------------|-------------|-----------------|
| INSERT | `INSERT`, `ISUPDATE = FALSE` | Insert current state |
| UPDATE | `DELETE` + `INSERT`, both `ISUPDATE = TRUE` | Ignore before-row delete; update from after-row insert |
| DELETE | `DELETE`, `ISUPDATE = FALSE` | Delete current state |

A Stream reports the net change between its offset and the current table version. It is not an immutable log of every intermediate transition. `ORDER_CHANGE_AUDIT` preserves the net rows that each successful consumer transaction observed.

## Retention And Recovery

The workshop uses one day of `DATA_RETENTION_TIME_IN_DAYS` and should be completed in one session. For production, set source retention or `MAX_DATA_EXTENSION_TIME_IN_DAYS` above the longest expected consumer outage plus diagnosis, repair, and replay margin. Consume before `STALE_AFTER`; the extension is a safety mechanism, not an operating SLA.

Do not run `CREATE OR REPLACE TABLE RAW_ORDERS` independently. Replacing the source destroys its history and stales attached Streams. If a Stream becomes stale, stop the consumer, recreate a synchronized source/target checkpoint, recreate the Stream at that checkpoint, validate reconciliation, and then resume processing.

Create a separate Stream for each independent consumer. Sharing one Stream makes the first successful DML consumer advance the offset for the others.

## Triggered Task

The Task has a `WHEN SYSTEM$STREAM_HAS_DATA(...)` condition and no schedule. Snowflake checks for change events without running warehouse SQL until triggered. It ships suspended so deployment does not start recurring compute.

The Task owner must have `EXECUTE TASK ON ACCOUNT`. If resume fails with an authorization error, an account administrator must grant that privilege to the owner role before retrying.

## Reset And Teardown

Rerun `deploy_all.sql` to restore the deterministic baseline. Deployment statements commit independently, so a failed redeployment can leave a partial schema; fix the reported error and rerun the full deploy script.

Run `teardown_all.sql` to suspend the Task and remove `STREAMS_CDC_WORKSHOP` plus `SFE_STREAMS_CDC_WH`. It preserves the shared `SNOWFLAKE_EXAMPLE` database, `GIT_REPOS` schema, Git repository, and API integration.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Stream is empty after source DML | DML rolled back or changed a different table | Confirm the transaction committed in the project schema |
| SELECT keeps returning the same rows | SELECT does not consume a Stream | Call `SP_CONSUME_ORDER_CHANGES()` or use Stream data in committed DML |
| Target differs from source | Consumer has not run or its transaction failed | Check the procedure result, then inspect pending Stream rows |
| Task will not resume | Owner lacks `EXECUTE TASK` or warehouse access | Grant the missing privilege to the task owner role |
| Stream reports stale | Offset exceeded retained source history | Rebuild from a synchronized checkpoint; do not trust stale output |
| MERGE is nondeterministic | Multiple current rows share an `ORDER_ID` | Restore key uniqueness before consuming the Stream |
| Optional Task check says `RETRY` | Triggered run is still queued or executing | Wait briefly and rerun script `07`; it leaves the Task resumed until consumption succeeds |

## Estimated Demo Costs

This demo uses an X-Small standard warehouse with 60-second auto-suspend. Deployment and the full workshop usually require only a few warehouse resumptions and a few minutes of runtime. Storage is negligible for the small tables, though an unconsumed Stream can extend retained source history and therefore increase storage on a real high-churn table.

No Cortex, Snowpipe, external function, or other serverless feature is used. Actual credit consumption depends on account configuration, cloud, region, and participant pacing.

## Development Tools

- `AGENTS.md` contains project-specific instructions for AI coding assistants.
- `.claude/skills/streams-cdc-workshop/SKILL.md` documents architecture and extension steps.
- `ELI5.md` explains the workshop without database jargon.

## Related Guides

- [Introduction to Streams](https://docs.snowflake.com/en/user-guide/streams-intro)
- [Triggered Tasks](https://docs.snowflake.com/en/user-guide/tasks-triggered)
- [Introduction to Streams and Tasks](https://docs.snowflake.com/en/user-guide/data-pipelines-intro)

## External References

- [CREATE STREAM](https://docs.snowflake.com/en/sql-reference/sql/create-stream)
- [TASK_HISTORY](https://docs.snowflake.com/en/sql-reference/functions/task_history)
- [Transactions](https://docs.snowflake.com/en/sql-reference/transactions)
