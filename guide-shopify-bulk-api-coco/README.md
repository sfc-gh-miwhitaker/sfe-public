![Guide](https://img.shields.io/badge/type-guide-blue)
![No Deploy](https://img.shields.io/badge/deploy-guided_by_CoCo-29B5E8)
![Expires](https://img.shields.io/badge/expires-2026--12--03-yellow)
![Status](https://img.shields.io/badge/status-ACTIVE-brightgreen)

# Build and Operate Shopify Ingestion with CoCo Desktop

This is not a guide to hand-coding a Shopify connector. It is a guide to using CoCo
Desktop to build and operate a Snowflake-native data product for dozens of Shopify
stores. Snowflake provides deterministic execution; CoCo provides the engineering
lifecycle: current documentation, generated implementation, deployment gates, smoke
testing, troubleshooting, and maintenance. Read-only automations provide continuous
supervision without putting an LLM in the data path.

**Audience:** Snowflake administrators and data engineers replacing a third-party
Shopify ELT service with a transparent, version-controlled Snowflake implementation.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-09-03 | **Expires:** 2026-12-03 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Start Here

Open this project in CoCo Desktop, connect to the target Snowflake account, and use this
prompt:

> Build this Shopify pipeline in the connected account. Read `AGENTS.md`, the project
> skill, and `coco/BUILD_PLAYBOOK.md` first. Verify current first-party documentation.
> Execute one deployment gate at a time and show evidence after each. Start with one
> store. Do not activate a store or resume the daily task until every gate passes.

CoCo reads the implementation, verifies it against current documentation, compiles and
deploys the objects, runs the pilot qualification, interprets the evidence, and stops on
the first failing boundary. The administrator reviews changes and decisions; they do not
memorize Snowflake system views or debug a Bulk Operation state machine alone.

### What runs where

| Responsibility | Surface | Reason |
|---|---|---|
| Build, deploy, qualify, troubleshoot, evolve | **CoCo Desktop** | It sees current docs, source code, Snowflake objects, query results, and run evidence together |
| Pull, land, and load data | **Python stored procedure + Snowflake Task** | Deterministic, testable, secure, and independent of an LLM response |
| Transform for analytics | **Dynamic Tables** | Declarative dependency and refresh management |
| Daily/weekly/monthly supervision | **CoCo automations** | Read-only investigation, prioritization, and maintenance reports |

The agent does not move production data. It builds and operates the machinery that does.

---

## Why This Path

The same Shopify requirement can be solved with Openflow. The difference is the operating
interface.

| Concern | Openflow Shopify connector | CoCo-managed native pipeline |
|---|---|---|
| Store onboarding | Gen 1 canvas install and parameter dialog per store | Add metadata, regenerate bindings, CoCo qualifies each store |
| Implementation | Flow hidden behind a connector process group | Inspectable SQL, Python, GraphQL, and tests in Git |
| Idle cost | Deployment management compute continues with no runtimes | No always-on service; task/warehouse run only when needed |
| Secrets | Sensitive connector parameters | Snowflake SECRET, readable only inside the procedure |
| Cost attribution | No per-runtime attribution for Snowflake deployments | Per-store `QUERY_TAG` and `QUERY_ATTRIBUTION_HISTORY` |
| Schema changes | State reset and table replacement | CoCo updates the query and typed Dynamic Table, then qualifies one store |
| Troubleshooting | NiFi canvas, queues, controller services, bulletins | CoCo correlates task, procedure, COPY, stage, and code evidence |
| Maintenance | Connector release lifecycle | CoCo monthly API/security review and controlled upgrade playbook |

This path is more code and less product. That does not mean administrators maintain it
alone. The code is the transparent operating surface CoCo uses to deploy correctly,
diagnose precisely, and evolve safely.

---

## Architecture

```
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
│   → internal stage → COPY INTO raw VARIANT                       │
│   → Dynamic Tables → orders, line items, fulfillments, daily KPI │
└───────────────────────────────────────────────────────────────────┘
        │ run logs + task history + query tags + qualification evidence
        ▼
CoCo automations (read-only)
  daily health / weekly cost+hygiene / monthly API+security
        │ dated reports + exact Desktop investigation prompts
        └──────────────────────────────▶ CoCo Desktop
```

### Security boundary

Each Shopify app's Client ID and Client Secret are stored as a Snowflake `PASSWORD`
SECRET. Snowflake never returns the password through `DESC SECRET`. The procedure gets a
fixed alias through its `SECRETS` clause and reads it with
`_snowflake.get_username_password`. Secret values never enter source files, prompts,
automation workspaces, or logs.

The aliases are fixed at procedure creation time. `tools/generate_store_bindings.py`
validates non-secret store metadata and emits the EAI allowlist, registry MERGE, procedure
`SECRETS` fragment, and store-to-alias map. CoCo runs this generator when stores change.

Cloud-agent documentation currently conflicts on arbitrary EAI support, and automations
have no documented general-purpose secret-value injection. Therefore automations never
call Shopify. They remain read-only supervisors.

---

## Deploy Right The First Time

"Right the first time" means proof before promotion, not pretending integration failures
cannot happen. `coco/BUILD_PLAYBOOK.md` makes these gates explicit:

| Gate | CoCo proves |
|---|---|
| Documentation | Current Shopify API, auth flow, limits, Snowflake runtime and external-access syntax |
| Security | Secrets remain in Snowflake; EAI and grants are least privilege; repository scan is clean |
| Compilation | SQL, embedded Python, and GraphQL parse before deployment |
| Connectivity | Shopify token endpoint succeeds through the EAI |
| Extraction | Bulk Operation reaches `COMPLETED` and returns a result URL |
| Landing | Non-empty JSONL file exists on the internal stage |
| Loading | COPY succeeds with explicit columns and no rejected rows |
| Contract | Required IDs, timestamps, and money fields exist |
| Reconciliation | Count and gross sales match the incumbent within agreed tolerances |
| Scheduling | Store becomes active and task resumes only after every prior gate passes |
| Rollback | Task suspend and dependency-ordered teardown are available |

The first store is a deployment qualification test. Every later store follows the proven
playbook independently.

---

## Implementation Map

| File | What CoCo uses it for |
|---|---|
| `sql/01_landing.sql` | Roles, warehouse, stage, registry, run log, qualification evidence, raw VARIANT table |
| `sql/02_network_secrets.sql` | Wildcard Shopify network rule, result host, EAI, interactive secret pattern |
| `config/stores.example.json` | Non-secret source of truth for generated bindings |
| `tools/generate_store_bindings.py` | Validates stores and generates EAI/procedure/registry fragments |
| `sql/03_pull_procedure.sql` | Token, Bulk Operation, polling, JSONL, `put_stream`, COPY, logging, all-store loop, qualification |
| `sql/04_schedule.sql` | Daily task, intentionally suspended |
| `sql/05_analytics_layer.sql` | Typed adaptive Dynamic Tables for orders, lines, fulfillments, and daily activity |
| `sql/06_monitoring.sql` | Health, zero-lag task history, per-store cost, qualification, stage inventory |
| `coco/BUILD_PLAYBOOK.md` | Evidence-gated deployment workflow |
| `coco/TROUBLESHOOTING_PLAYBOOK.md` | Boundary-first incident investigation |
| `coco/MAINTENANCE_PLAYBOOK.md` | Add store/object, backfill, rotate, pause, API upgrade |

---

## Build With CoCo Desktop

### 1. Prepare Shopify

Create and install one dev app per store. Grant the minimum scopes:

| Scope | Use |
|---|---|
| `read_orders` | Orders, transactions, and fulfillments; about 60 days by default |
| `read_all_orders` | Older order history; requires Shopify approval |
| `read_merchant_managed_fulfillment_orders` | Fulfillment orders |

Customer details are intentionally omitted. `read_customers` involves protected customer
data and a separate Shopify approval.

### 2. Let CoCo deploy the foundation

Use the Start Here prompt. CoCo runs `01_landing.sql`, then the network-rule portion of
`02_network_secrets.sql`. You enter each Client ID and Client Secret only in a private
worksheet statement. After every referenced secret exists, CoCo runs the generator output
to create the EAI and procedure bindings. It verifies metadata with `DESC SECRET`; it
never asks for or reads the value.

### 3. Register stores through the generator

Create `config/stores.json` from the example and add non-secret metadata. Ask:

> Validate `config/stores.json`, generate store bindings, show the diff, compile the
> procedure, and deploy it with every new store inactive.

The generator rejects invalid keys, non-`myshopify.com` domains, malformed FQNs, and
duplicates before it emits SQL.

### 4. Qualify one store

```sql
CALL SHOPIFY_NATIVE.CONTROL.QUALIFY_STORE('STORE_ALPHA', NULL);

SELECT STORE_KEY, GATE_NAME, PASSED, EVIDENCE
FROM SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS
WHERE STORE_KEY = 'STORE_ALPHA'
ORDER BY CHECKED_AT, GATE_NAME;
```

For a migration, load the incumbent daily counts and gross sales into
`RECONCILIATION_BASELINE`, then pass its `SOURCE_NAME` instead of `NULL`. CoCo explains
timezone, refunds, test orders, and history-window differences; it does not wave them away.

### 5. Promote

Ask CoCo to review the evidence. Only if every gate passed:

```sql
UPDATE SHOPIFY_NATIVE.CONTROL.STORE_REGISTRY
SET IS_ACTIVE = TRUE
WHERE STORE_KEY = 'STORE_ALPHA' AND QUALIFICATION_STATUS = 'PASSED';

EXECUTE TASK SHOPIFY_NATIVE.CONTROL.DAILY_SHOPIFY_PULL;
ALTER TASK SHOPIFY_NATIVE.CONTROL.DAILY_SHOPIFY_PULL RESUME;
```

`EXECUTE TASK` proves the scheduled owner-role path before the schedule is enabled.

---

## How The Deterministic Pull Works

1. Look up the store in the generated map and select its fixed secret alias.
2. Exchange Client ID/Secret at `/admin/oauth/access_token`. Tokens last about 24 hours;
   a daily run gets a fresh token instead of persisting one.
3. Start `bulkOperationRunQuery`. API 2026-01+ permits up to five concurrent query bulk
   operations per app per shop.
4. Poll the operation by ID every 30 seconds. The task timeout and warehouse statement
   timeout are both two hours; the lower non-zero setting wins.
5. Download the JSONL result before its seven-day URL expiry.
6. Write bytes with `session.file.put_stream`. SQL `PUT` is unsupported in stored
   procedures.
7. COPY the exact file into one raw VARIANT table with store, object, file, row, and load
   metadata. COPY's load history prevents accidental duplicate file loads.
8. Log success or failure with run ID, operation ID, counts, watermark, error, and query ID.

Failures are isolated by store and object in `PULL_ALL_STORES`; one store does not prevent
the rest from running.

---

## Troubleshoot With CoCo

Ask:

> Why did Shopify ingestion fail last night?

The project skill routes CoCo through `coco/TROUBLESHOOTING_PLAYBOOK.md`. It queries
`V_PIPELINE_HEALTH`, `PULL_RUN_LOG`, zero-lag `TASK_HISTORY`, COPY/query history, stage
inventory, and the relevant code. It finds the first failing boundary — task,
privilege, token, GraphQL, bulk operation, download, stage, COPY, Dynamic Table, or
reconciliation — before proposing a repair.

The close criteria are deliberately strict: evidence-backed root cause, one-store retry,
current raw and typed freshness, no unrelated replay, original task state restored, and a
durable prevention change.

This is the advantage of transparent code: CoCo can inspect implementation and runtime
evidence together. A managed connector's support boundary often separates the two.

---

## Maintain With CoCo

`coco/MAINTENANCE_PLAYBOOK.md` contains paste-ready prompts for:

- Adding a store with generated secret bindings and qualification.
- Adding a Shopify object or field with scope, GraphQL, and DT validation.
- Backfilling after `read_all_orders` approval.
- Rotating credentials without exposing values.
- Pausing or retiring a store while preserving history.
- Rolling the Shopify API version through one-store qualification before fleet rollout.

This converts maintenance from "find the person who remembers the Python" into a
repeatable, evidence-gated CoCo workflow.

---

## Supervise With Automations

The automations are the operations engineer, not the data mover.

| Cadence | Checks | Output |
|---|---|---|
| Daily 07:00 | Store freshness, last task, failures, 14-day same-weekday anomalies | `shopify/status-YYYY-MM-DD.md` + exact investigation prompts |
| Weekly Monday 08:00 | Cost by store, stage hygiene, registry/schedule drift, qualification | `shopify/weekly-YYYY-MM-DD.md` |
| Monthly day 1 09:00 | Shopify API/deprecations, runtime/packages, secrets metadata, EAI, grants, timeout, DT health | `shopify/monthly-YYYY-MM-DD.md` |

Create them from CoCo Desktop's terminal after setting the timezone:

```bash
SHOPIFY_AUTOMATION_TIMEZONE=America/Los_Angeles bash coco/create_automations.sh
cortex automation execute shopify_pipeline_daily --wait
cortex automation doctor shopify_pipeline_daily
```

Automations run as the creating user's default role and secondary roles. Use a user whose
defaults have read-only access to the control/analytics objects. They write complete dated
files because the workspace mount does not support appending.

---

## Honest Costs And Boundaries

CoCo removes toil; it does not repeal the Shopify API.

- You own the GraphQL selection, JSONL contract, and API version. CoCo makes that ownership
  inspectable and repeatable.
- Shopify app creation, scope approval, release, and installation remain Shopify admin work.
- `read_orders` still has the default history limit; `read_all_orders` still needs approval.
- A Bulk Operation can fail inside Shopify. The run log keeps its ID so CoCo can diagnose
  rather than restart the fleet blindly.
- Result hosts must be allowed by the EAI. The initial design includes
  `storage.googleapis.com`, which Snowflake's Shopify connector documentation identifies;
  verify the actual first result URL before production.
- The raw stage needs a retention policy. Weekly supervision flags inventory; deletion is
  an explicit administrator decision.
- Automations are time-based (minimum hourly), have no local filesystem, and should not
  mutate this pipeline unattended.

This is not "no operations." It is Snowflake-native operations with the correct tool at
each layer.

---

## Cutover From The Incumbent

1. Qualify one store while the incumbent remains live.
2. Reconcile at least three daily cycles: order count, gross sales, refunds, and
   fulfillment count by store/date/currency.
3. Move one report to `SHOPIFY_NATIVE.ANALYTICS` and obtain owner acceptance.
4. Add stores in batches of five; each store qualifies independently.
5. Keep the incumbent until the new path has survived a credential rotation, API-version
   qualification, and a controlled failed-store retry.

CoCo performs and documents the checks. The business owner decides when evidence is good
enough to cut over.

---

## Related Guides

- [CoCo Desktop guide](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop)
- [CoCo automations](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-automations)
- [Snowflake external network access](https://docs.snowflake.com/en/developer-guide/external-network-access/creating-using-external-network-access)
- [Snowflake secret API](https://docs.snowflake.com/en/developer-guide/external-network-access/secret-api-reference)
- [Snowpark `put_stream`](https://docs.snowflake.com/en/developer-guide/snowpark/reference/python/latest/snowpark/api/snowflake.snowpark.FileOperation.put_stream)
- [Shopify bulk query operations](https://shopify.dev/docs/api/usage/bulk-operations/queries)

---

## External References

- CoCo cloud sandbox: https://docs.snowflake.com/en/user-guide/cortex-code/cloud-sandbox
- CoCo automations: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-automations
- Python stored procedure limitations: https://docs.snowflake.com/en/developer-guide/stored-procedure/python/procedure-python-limitations
- External access setup: https://docs.snowflake.com/en/developer-guide/external-network-access/creating-using-external-network-access
- External access best practices: https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-best-practices
- CREATE SECRET: https://docs.snowflake.com/en/sql-reference/sql/create-secret
- DESC SECRET: https://docs.snowflake.com/en/sql-reference/sql/desc-secret
- Snowpark `put_stream`: https://docs.snowflake.com/en/developer-guide/snowpark/reference/python/latest/snowpark/api/snowflake.snowpark.FileOperation.put_stream
- Snowflake Tasks: https://docs.snowflake.com/en/user-guide/tasks-intro
- Dynamic Tables: https://docs.snowflake.com/en/user-guide/dynamic-tables/overview
- Snowpipe auto-ingest: https://docs.snowflake.com/en/user-guide/data-load-snowpipe-auto
- Directory tables: https://docs.snowflake.com/en/user-guide/data-load-dirtables
- Shopify Bulk Operations: https://shopify.dev/docs/api/usage/bulk-operations/queries
- Shopify client credentials: https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/client-credentials-grant
- Shopify access scopes: https://shopify.dev/docs/api/usage/access-scopes
