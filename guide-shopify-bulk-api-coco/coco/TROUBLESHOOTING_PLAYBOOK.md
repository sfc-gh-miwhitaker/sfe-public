# CoCo Troubleshooting Playbook

Pair-programmed by SE Community + Cortex Code

## Operator Prompt

> Why did Shopify ingestion fail last night? Read the project skill and source first.
> Query `V_PIPELINE_HEALTH`, `PULL_RUN_LOG`, zero-lag `TASK_HISTORY`, COPY/query history,
> qualification evidence, and the relevant procedure code. Identify the first failing
> boundary, cite the evidence, verify the current product docs, propose the smallest safe
> repair, test one affected store, and prove freshness before closing. Never retrieve or
> display a secret value.

## Boundary Map

| Boundary | Evidence | Common cause | Repair pattern |
|---|---|---|---|
| Task did not fire | `TASK_HISTORY`, `SHOW TASKS` | Suspended task, owner privilege | Preserve prior state; fix grant; resume only if previously resumed |
| Procedure did not start | task error + `SHOW GRANTS TO ROLE` | Missing EAI/warehouse/procedure privilege | Add least privilege; retry one store |
| Token request | `PULL_RUN_LOG.ERROR_MESSAGE` | App not installed/released; wrong secret; missing scope | Verify app state; rotate secret without exposing it |
| GraphQL validation | `SHOPIFY_VALIDATION` | Unsupported field or missing scope | Verify API docs; remove/replace field; reinstall app after scope change |
| Bulk operation | operation ID and status | Shopify internal failure, timeout, competing operations | Poll operation by ID; retry the store/object only |
| Result download | HTTP status; EAI history | Expired URL or missing result host | Re-run operation; update network rule after verifying host |
| Stage write | procedure error; stage inventory | `put_stream` privilege/path | Fix stage privilege; do not replace with unsupported SQL `PUT` |
| COPY | COPY output; query history | Malformed JSONL, file format, table contract | Quarantine file; fix parser; reload that file only |
| Dynamic Table | refresh history | Cast/schema drift | Use `TRY_*`; add field through maintenance playbook |
| Reconciliation | baseline vs daily model | timezone, 60-day window, refunds, test orders | Explain delta; do not promote until accepted |

## Close Criteria

- Root cause is linked to evidence, not inferred from the last error alone.
- One-store retry succeeded.
- Raw and typed freshness are current.
- No unrelated store was replayed.
- Task state matches its pre-incident state.
- A durable code, test, runbook, or monitor change prevents recurrence.
