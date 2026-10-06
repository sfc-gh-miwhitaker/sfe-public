# CoCo Troubleshooting Playbook

Pair-programmed by SE Community + Cortex Code

## Operator Prompt

> Why did Shopify ingestion fail last night? Read the project skill and source first.
> Query `V_PIPELINE_HEALTH`, `PULL_RUN_LOG`, zero-lag `TASK_HISTORY`, COPY/query history,
> qualification evidence, and the relevant procedure code. Identify the first failing
> boundary, cite the evidence, verify the current product docs, propose the smallest safe
> repair, test one affected store, and prove freshness before closing. Never retrieve or
> display a secret value.

The classifier in `sql/native/06_monitoring.sql` query G maps the run log's error text to
a first failing boundary. Start there, then confirm against the evidence column below
rather than trusting the label.

## Boundary Map

| Boundary | Evidence | Common cause | Repair pattern |
| --- | --- | --- | --- |
| Task did not fire | `TASK_HISTORY`, `SHOW TASKS` | Suspended task, owner privilege | Preserve prior state; fix grant; resume only if previously resumed |
| Procedure did not start | task error + `SHOW GRANTS TO ROLE` | Missing EAI/warehouse/procedure privilege | Add least privilege; retry one store |
| Token request | `PULL_RUN_LOG.ERROR_MESSAGE` | App not installed/released; wrong secret; missing scope | Verify app state; rotate secret without exposing it |
| GraphQL validation | `SHOPIFY_VALIDATION` | Unsupported field or missing scope | Verify API docs; remove/replace field; reinstall app after scope change |
| Bulk operation | operation ID and status | Shopify internal failure, timeout, or all five of this app's concurrent query slots in flight for the shop | Poll the operation by ID; list `bulkOperations` before assuming contention; retry that store and object only |
| Result download | HTTP status; EAI history | Expired URL or missing result host | Re-run operation; update network rule after verifying host |
| Stage write | procedure error; stage inventory | `put_stream` privilege/path | Fix stage privilege; do not replace with unsupported SQL `PUT` |
| COPY | COPY output; query history | Malformed JSONL, file format, table contract | Quarantine file; fix parser; reload that file only |
| Dynamic Table | refresh history | Cast/schema drift | Use `TRY_*`; add field through maintenance playbook |
| Reconciliation | baseline vs the published contract view | timezone, 60-day window, refunds, test orders | Explain the delta; do not promote until accepted |
| Contract drift | `V_CONTRACT_CONFORMANCE` | implementation changed without updating the contract | Fix the implementation, or change README.md and `CONTRACT_COLUMNS` deliberately |
| Grain fan-out | `sql/shared/03_monitoring.sql` query E | a join lost its currency predicate | Restore the full `(store_key, activity_date, currency_code)` predicate |

## Close Criteria

- Root cause is linked to evidence, not inferred from the last error alone.
- One-store retry succeeded.
- Raw and typed freshness are current.
- No unrelated store was replayed.
- Task state matches its pre-incident state.
- A durable code, test, runbook, or monitor change prevents recurrence.
