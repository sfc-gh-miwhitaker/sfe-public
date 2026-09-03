---
name: guide-shopify-bulk-api-coco
description: >
  Operate the CoCo-managed Shopify Bulk API pipeline. Use for setup, adding stores,
  qualification, backfills, troubleshooting failed pulls, credential rotation,
  schema evolution, reconciliation, cost review, API upgrades, pausing stores, and
  pipeline health. Triggers: Shopify ingestion, Shopify pull failed, add Shopify store,
  Shopify backfill, Shopify API version, reconcile Shopify, rotate Shopify secret.
---

# Shopify Bulk API Pipeline Operator

## Purpose

Use CoCo Desktop to build, qualify, operate, troubleshoot, and evolve the deterministic
Snowflake-native Shopify ingestion pipeline. Keep the agent outside the data path.

## Architecture

`CoCo Desktop → deployment gates → Snowflake procedure/task → Shopify → stage/COPY → Dynamic Tables`

`CoCo automation → read-only health evidence → report → CoCo Desktop repair playbook`

## Operating Contract

1. Read the relevant SQL and current Snowflake/Shopify docs before changing behavior.
2. Diagnose from `PULL_RUN_LOG`, `TASK_HISTORY`, COPY results, and source code together.
3. Test one store and one object before widening scope.
4. Resume the scheduled task only after every qualification gate passes.
5. Never display or retrieve a secret value.

## Key Files

| File | Purpose |
|---|---|
| `README.md` | CoCo-first build and operations guide |
| `sql/01_landing.sql` | Roles, registry, logs, stage, raw tables |
| `sql/02_network_secrets.sql` | Network rule, EAI, secret registration pattern |
| `sql/03_pull_procedure.sql` | Deterministic Bulk API pull/load procedure |
| `sql/04_schedule.sql` | Suspended daily task and promotion gate |
| `sql/05_analytics_layer.sql` | Typed Dynamic Tables |
| `sql/06_monitoring.sql` | Health, cost, task, COPY diagnostics |
| `coco/BUILD_PLAYBOOK.md` | Guided build and qualification gates |
| `coco/TROUBLESHOOTING_PLAYBOOK.md` | Evidence-first incident workflow |
| `coco/MAINTENANCE_PLAYBOOK.md` | Store, schema, secret, and API lifecycle |
| `coco/automation_*.md` | Daily, weekly, and monthly supervision prompts |

## Extension Playbook: Add A Store

1. Confirm Shopify app scopes and `read_all_orders` requirement.
2. Create the store's PASSWORD secret without exposing its value in chat or files.
3. Add the secret to the EAI allowlist and register its fully qualified name.
4. Run `QUALIFY_STORE` with scheduling still suspended.
5. Inspect all gate results and reconcile against the incumbent if supplied.
6. Mark the store active only after qualification passes.

## Gotchas

- CoCo builds and operates the pipeline; the stored procedure moves the data.
- Cloud-agent EAI support is conflicting in current docs. Do not call Shopify from an automation.
- `Session.sql("PUT")` is unsupported in stored procedures; use `session.file.put_stream`.
- Shopify result URLs expire after seven days.
- API 2026-01+ allows five concurrent query bulk operations per app per shop.
- `read_orders` is limited to about 60 days without `read_all_orders` approval.
- Snowpipe auto-ingest is for external stages; this internal-stage design uses COPY.
- Workspace mounts do not support append. Automations overwrite a dated report file.
