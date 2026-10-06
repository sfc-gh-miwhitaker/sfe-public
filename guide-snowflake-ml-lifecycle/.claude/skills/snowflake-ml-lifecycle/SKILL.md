---
name: snowflake-ml-lifecycle
description: "Evaluation guide for teams on AWS/SageMaker: Snowflake ML end-to-end design (Feature Store, ML Jobs, Model Registry, warehouse and SPCS inference, task-graph retraining, ML Lineage), model monitoring, a serving bake-off method, cross-cloud registry patterns, and deployed-model cost drivers."
---

# Snowflake ML Lifecycle — SE Guide

## Purpose

Answers five evaluation questions: end-to-end design, monitoring, serving versus AWS,
cross-cloud registry, and total compute cost. Thesis: design once, measure your own numbers.
No parity claims anywhere — section 3 is a bake-off protocol.

## Architecture

```text
README.md                    <- 5-section narrative + Mermaid flow + misconceptions
ELI5.md                      <- restaurant-kitchen plain-language companion
python/reference_pipeline.py <- FS -> @remote ML Job -> log_model -> mv.run -> create_service -> DAG
sql/monitoring_queries.sql   <- inference log, baseline, CREATE MODEL MONITOR, metric queries, ALERT
sql/lineage_audit.sql        <- GET_LINEAGE upstream/downstream
sql/cost_drivers.sql         <- 7 ACCOUNT_USAGE cost queries (credits)
```

## Key Files

| File | Role |
| --- | --- |
| `README.md` | Primary deliverable |
| `sql/cost_drivers.sql` | Compiled against real ACCOUNT_USAGE columns |
| `sql/monitoring_queries.sql` | Needs a registered model; not compile-checkable without one |
| `python/reference_pipeline.py` | Illustrative; placeholders `ML_DB.ML`, `ML_WH`, `ML_CPU_POOL` |

## Snowflake Objects

None deployed. The SQL files contain DDL (monitor, alert, tables) the reader runs themselves.
Needs: `IMPORTED PRIVILEGES` on `SNOWFLAKE`, `VIEW LINEAGE` on account, Enterprise for lineage.

## Extension Playbook

### Add a new cost driver

1. Confirm the ACCOUNT_USAGE view and columns in docs.
2. Add a numbered query to `sql/cost_drivers.sql` with a comment naming what bills and the control.
3. Compile it (`only_compile=true`) against a live account.
4. Add a row to the README section 5 table; if it overlaps another view, say "do not add".

### Add a monitor metric or alert

1. Check the metric name exists for the model's `task` (regression vs binary vs multiclass).
2. Add the query to `sql/monitoring_queries.sql` with explicit columns
   (`event_timestamp, metric_name, [column_name,] metric_value`).
3. For alerts, filter to the last complete bucket (`QUALIFY ROW_NUMBER() ... = 1`).
4. Update README section 2's table.

### Refresh at expiry

Re-verify Preview items (Postgres online store, stream feature views, feature groups,
`feature_sources_per_function`, gateway monitors) and every status in the section 1 table.

## Gotchas

- **Pool vs service idle.** `min_instances=0` suspends the service after 30 min; the pool
  (`MIN_NODES >= 1`) bills until `AUTO_SUSPEND_SECS` (default 3600). Never conflate them.
- **Baseline snapshot.** The monitor copies the baseline at CREATE time. Empty baseline = no drift, ever.
- **Monitor column lists are quoted strings:** `ID_COLUMNS = ('CUSTOMER_ID')`.
- **Lineage domains:** feature view = `'TABLE'`, model = `'MODULE'`; no `FEATURE_VIEW` domain.
- **Lineage needs Snowpark sample input.** A pandas `sample_input_data` records no dataset lineage.
- **`MODEL_SERVING_USAGE_HISTORY` overlaps pool credits.** It is attribution; never sum with query 1.
- **`@remote` in a DAG:** `DAGTask("T", definition=fn)`, no warehouse, no arguments.
- **`CREATE ALERT` does not validate the condition**, and alerts start suspended.

Pair-programmed by SE Community + Cortex Code
