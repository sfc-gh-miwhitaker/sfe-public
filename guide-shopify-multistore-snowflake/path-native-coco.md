# Path: Native Bulk API Pipeline, Operated with CoCo Desktop

Pair-programmed by SE Community + Cortex Code

The native implementation: external access and secrets, generated per-store bindings, the
deterministic pull procedure, qualification gates, CoCo Desktop playbooks, and read-only
supervision automations.

> **Read [README.md](./README.md) first.** The path decision, the Shopify-side app and
> scope work, the API version choice, the shared store registry, the analytics contract,
> the monitoring intent, and the cutover runbook are stated there once and are not
> repeated here.

This is not a guide to hand-coding a Shopify connector. It is a guide to using CoCo
Desktop to build and operate a Snowflake-native data product for dozens of stores.
Snowflake provides deterministic execution; CoCo provides the engineering lifecycle:
current documentation, generated implementation, deployment gates, smoke testing,
troubleshooting, and maintenance. Read-only automations supervise it without putting an
LLM in the data path.

Every component is GA.

---

## Start Here

Open this project in CoCo Desktop, connect to the target Snowflake account, and use the
start prompt in **[coco/BUILD_PLAYBOOK.md](./coco/BUILD_PLAYBOOK.md)**.

That playbook is the single definition of the gate sequence, the pilot command, and the
promotion statements. It is what CoCo reads, so it is not restated here — follow it rather
than this file for the build itself.

CoCo reads the implementation, verifies it against current documentation, compiles and
deploys the objects, runs the pilot qualification, interprets the evidence, and stops on
the first failing boundary. The administrator reviews changes and decisions; they do not
memorize Snowflake system views or debug a Bulk Operation state machine alone.

### What runs where

| Responsibility | Surface | Reason |
| --- | --- | --- |
| Build, deploy, qualify, troubleshoot, evolve | **CoCo Desktop** | It sees current docs, source, Snowflake objects, query results, and run evidence together |
| Pull, land, and load data | **Python stored procedure + Snowflake Task** | Deterministic, testable, secure, independent of an LLM response |
| Transform for analytics | **Dynamic Tables** | Declarative dependency and refresh management |
| Daily/weekly/monthly supervision | **CoCo automations** | Read-only investigation, prioritization, and maintenance reports |

The agent does not move production data. It builds and operates the machinery that does.

---

## Architecture

```text
Snowflake administrator
        │ plain-language build / operate / repair requests
        ▼
CoCo Desktop ── docs + code + catalog + SQL results + deployment gates
        │ creates, compiles, deploys, qualifies
        ▼
┌──────────────── Deterministic Snowflake data path ────────────────┐
│ Snowflake TASK (daily, suspended until qualification passes)      │
│   → Python procedure (EAI + fixed SECRET bindings)                │
│   → Shopify client-credentials token                              │
│   → bulkOperationRunQuery → poll by operation ID                  │
│   → signed JSONL result → session.file.put_stream                 │
│   → internal stage → COPY INTO raw VARIANT                        │
│   → Dynamic Tables → orders, line items, fulfillments, daily KPI  │
└───────────────────────────────────────────────────────────────────┘
        │ run logs + task history + query tags + qualification evidence
        ▼
CoCo automations (read-only)
  daily health / weekly cost+hygiene / monthly API+security
        │ dated reports + exact Desktop investigation prompts
        └──────────────────────────────▶ CoCo Desktop
                     │
                     ▼
     SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY   ← the published contract
```

Three databases:

| Database | Holds | Who writes |
| --- | --- | --- |
| `SHOPIFY_CONTROL` | Shared registry, baseline, contract, published views | Admin (path-independent) |
| `SHOPIFY_NATIVE.CONTROL` | Run log, qualification evidence, procedures, task | Pipeline role |
| `SHOPIFY_NATIVE.LANDING` / `.ANALYTICS` | Stage, raw VARIANT table / Dynamic Tables | Procedure / DT refresh |

---

## Security boundary

Each Shopify app's Client ID and Client Secret are stored as a Snowflake `PASSWORD`
secret. Snowflake never returns the password through `DESC SECRET`. The procedure gets a
fixed alias through its `SECRETS` clause and reads it with
`_snowflake.get_username_password`. Secret values never enter source files, prompts,
automation workspaces, or logs.

The aliases are fixed at procedure creation time. `tools/generate_store_bindings.py`
validates non-secret store metadata and emits, in a deliberately safe order, the EAI and
its `ALLOWED_AUTHENTICATION_SECRETS` list, the `READ` grants, the MERGE into the shared
registry, and the `SECRETS` fragment plus store-to-alias map. The EAI is created only
after every secret it references exists, which avoids an undeployable placeholder
reference. CoCo runs this generator whenever stores change.

Rotation replaces a secret in place; the procedure binds by name, so no redeployment is
needed. **Adding** a store does require regenerating bindings and redeploying the
procedure, because the alias list is fixed.

Cloud-agent documentation currently conflicts on arbitrary EAI support, and automations
have no documented general-purpose secret-value injection. Therefore **automations never
call Shopify.** They remain read-only supervisors.

Unlike the Openflow path, the network rule is a single wildcard
(`*.myshopify.com:443`) and never needs altering per store. The per-store boundary here is
the secret and the EAI allowlist, not the host list.

---

## Build

The gate sequence, the pilot command, and the promotion statements live in
**[coco/BUILD_PLAYBOOK.md](./coco/BUILD_PLAYBOOK.md)**. What follows is only what that
playbook does not cover.

### Order of deployment

| # | File | Note |
| --- | --- | --- |
| 1 | `sql/shared/01_store_registry.sql` | Shared. Deploy before anything else |
| 2 | `sql/shared/02_analytics_contract.sql` | Shared. Contract as data |
| 3 | `sql/native/01_landing.sql` | Role, warehouse, stage, run log, raw table |
| 4 | `sql/native/02_network_secrets.sql` | Network rule only, then **stop** |
| 5 | *manual* | Create each store's `PASSWORD` secret through private worksheet input |
| 6 | `tools/generate_store_bindings.py` | Emits EAI, grants, registry MERGE, procedure bindings |
| 7 | `sql/native/03_pull_procedure.sql` | With the generated fragments pasted in |
| 8 | `sql/native/04_schedule.sql` | Task created **suspended** |
| 9 | `sql/native/05_analytics_layer.sql` | Dynamic Tables + the two published views |
| 10 | `sql/native/06_monitoring.sql` | Health view and diagnostics |

### Register stores through the generator

Create `config/stores.json` from `config/stores.example.json` and add non-secret metadata.
Then ask CoCo:

> Validate `config/stores.json`, generate store bindings, show the diff, compile the
> procedure, and deploy it with every new store inactive.

The generator rejects invalid store keys, non-`myshopify.com` domains, malformed FQNs, and
duplicates before it emits any SQL. Its MERGE deliberately does not touch `IS_ACTIVE`: new
stores stay inactive until their gates pass.

---

## How the deterministic pull works

1. Look up the store in the generated map and select its fixed secret alias.
2. Exchange Client ID/Secret at `/admin/oauth/access_token`. Tokens last about 24 hours; a
   daily run gets a fresh token rather than persisting one.
3. Start `bulkOperationRunQuery`. On API 2026-01 and later each app gets up to five
   concurrent bulk query operations per shop, and the limit is per app — another vendor's
   integration on the same store does not consume your slots.
4. **Poll the operation by ID** every 30 seconds. `currentBulkOperation` is not used: with
   five possible in flight it cannot identify yours. The task timeout and the warehouse
   statement timeout are both two hours; the lower non-zero setting wins.
5. Download the JSONL result before its **seven-day** URL expiry. A valid zero-record
   operation returns a null URL, which is handled rather than treated as a failure.
6. Write bytes with `session.file.put_stream`. SQL `PUT` is unsupported in stored
   procedures; do not substitute it.
7. COPY the exact file into one raw VARIANT table with store, object, file, row, and load
   metadata. COPY's load history prevents accidental duplicate file loads.
8. Log success or failure with run ID, operation ID, counts, watermark, error, and query
   ID. The run log is the only place a failed bulk operation ID survives, which is what
   makes diagnosis possible at all.

Failures are isolated by store and object in `PULL_ALL_STORES`: one store does not prevent
the rest from running, though the procedure still raises so the task is marked failed.

**Object grouping is off by default on 2026-01 and later**, so a child record does not
reliably follow its parent in the JSONL. Every child Dynamic Table joins to its parent by
`__parentId` within the same `SOURCE_FILE`. Nothing in this path depends on row order.

---

## Qualification

`QUALIFY_STORE` extracts one day for one store **with the schedule suspended and the store
inactive**, then records pass/fail evidence per gate in `QUALIFICATION_RESULTS` and stamps
`QUALIFICATION_STATUS` on the shared registry.

This is the native path's structural advantage: it can prove a store's numbers before that
store is promoted into production. The Openflow path cannot, because it has no way to
extract without starting its connector.

"Right the first time" means proof before promotion, not pretending integration failures
cannot happen. The gate table in
[coco/BUILD_PLAYBOOK.md](./coco/BUILD_PLAYBOOK.md#gates) is the authoritative list.

---

## Troubleshoot

Ask:

> Why did Shopify ingestion fail last night?

The project skill routes CoCo through
[coco/TROUBLESHOOTING_PLAYBOOK.md](./coco/TROUBLESHOOTING_PLAYBOOK.md). It queries
`V_PIPELINE_HEALTH`, `PULL_RUN_LOG`, zero-lag `TASK_HISTORY`, COPY and query history, stage
inventory, and the relevant code. It finds the first failing boundary — task, privilege,
token, GraphQL, bulk operation, download, stage, COPY, Dynamic Table, contract, grain, or
reconciliation — before proposing a repair. Query G in `sql/native/06_monitoring.sql`
gives it a starting classification from the run log's error text.

The close criteria are deliberately strict: evidence-backed root cause, one-store retry,
current raw and typed freshness, no unrelated replay, original task state restored, and a
durable prevention change.

This is the advantage of transparent code: CoCo can inspect implementation and runtime
evidence together. A managed connector's support boundary often separates the two.

---

## Maintain

[coco/MAINTENANCE_PLAYBOOK.md](./coco/MAINTENANCE_PLAYBOOK.md) holds paste-ready prompts
for adding a store, adding a Shopify object or field, backfilling after `read_all_orders`
approval, rotating credentials without exposing values, pausing or retiring a store,
rolling the Shopify API version through one-store qualification, and switching
implementation paths.

Note that a scope change requires releasing a new app version and **reinstalling** before
testing: a working secret does not imply the token carries the new scope.

---

## Supervise with automations

The automations are the operations engineer, not the data mover.

| Cadence | Checks | Output |
| --- | --- | --- |
| Daily 07:00 | Store freshness, last task, failures, 14-day same-weekday anomalies | `shopify/status-YYYY-MM-DD.md` + exact investigation prompts |
| Weekly Monday 08:00 | Cost by store, stage hygiene, registry/schedule drift, qualification, contract conformance | `shopify/weekly-YYYY-MM-DD.md` |
| Monthly day 1 09:00 | Shopify API/deprecations, runtime/packages, secret metadata, EAI, grants, timeout, DT health | `shopify/monthly-YYYY-MM-DD.md` |

Create them from CoCo Desktop's terminal after setting the timezone:

```bash
SHOPIFY_AUTOMATION_TIMEZONE=America/Los_Angeles bash coco/create_automations.sh
cortex automation execute shopify_pipeline_daily --wait
cortex automation doctor shopify_pipeline_daily
```

Automations run as the creating user's default role and secondary roles. Use a user whose
defaults have read-only access to the control and analytics objects. They write complete
dated files because the workspace mount does not support appending.

---

## Honest costs and boundaries

CoCo removes toil; it does not repeal the Shopify API.

- You own the GraphQL selection, the JSONL contract, and the API version pin. CoCo makes
  that ownership inspectable and repeatable, not smaller.
- Shopify app creation, scope approval, release, and installation remain Shopify admin
  work — identical to the Openflow path.
- `read_orders` still has the 60-day window; `read_all_orders` still needs approval.
- A bulk operation can fail inside Shopify. The run log keeps its ID so CoCo can diagnose
  rather than restart the fleet blindly.
- Result hosts must be allowed by the EAI. The design includes
  `storage.googleapis.com`, which Snowflake's Shopify connector documentation identifies;
  verify the actual first result URL before production.
- The raw stage grows without bound and needs a retention policy. Weekly supervision flags
  inventory; deletion is an explicit administrator decision.
- Automations are time-based (minimum hourly), have no local filesystem, and must not
  mutate this pipeline unattended.
- Adding a store requires regenerating bindings and redeploying the procedure. Scriptable,
  but not zero.

This is not "no operations." It is Snowflake-native operations with the correct tool at
each layer.

---

## Teardown

`sql/native/07_teardown.sql`, in dependency order: suspend and drop the task, drop the
published views, drop the EAI, then the database, warehouse, and roles.

Dropping `SHOPIFY_NATIVE` destroys the raw stage and every landed JSONL file. That is
irreversible past Time Travel; export first if you need the history.

Store secrets are dropped explicitly and only after confirming no procedure binding or EAI
allowlist still references them. The teardown leaves `SHOPIFY_CONTROL` in place, because
the registry, the reconciliation baseline, and the contract survive a migration to the
Openflow path.

Uninstall the Shopify dev app in each store's Dev Dashboard separately; Snowflake cannot
revoke Shopify credentials.
