# Snowflake Streams CDC Workshop - Project Instructions

<!-- Global rules apply via ~/.claude/CLAUDE.md and rules/. Do not duplicate them here. -->

Pair-programmed by SE Community + Cortex Code

## Architecture

`RAW_ORDERS` feeds `RAW_ORDERS_STREAM`. `SP_CONSUME_ORDER_CHANGES` reads one
repeatable stream snapshot inside a transaction, writes every CDC row to
`ORDER_CHANGE_AUDIT`, and merges the current state into `CURRENT_ORDERS`.
`TASK_CONSUME_ORDER_CHANGES` optionally calls the procedure when the stream has data.

## Snowflake Environment

- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `STREAMS_CDC_WORKSHOP`
- Warehouse: `SFE_STREAMS_CDC_WH`

## Conventions

- Deployment establishes an empty stream over a synchronized source and target.
- Workshop scripts are stateful and must be run in numeric order.
- The triggered task ships suspended and is enabled only in the optional exercise.
- Reset by rerunning `deploy_all.sql`; do not replace `RAW_ORDERS` independently.

## Key Commands

- Deploy: run `deploy_all.sql` from a Snowsight worksheet.
- Workshop: run the scripts under `sql/04_workshop/` in numeric order.
- Validate: run `sql/98_validation/01_smoke_tests.sql` after each batch.
- Teardown: run `teardown_all.sql`.
