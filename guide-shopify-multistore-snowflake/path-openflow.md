# Path: Openflow Shopify Connector

Pair-programmed by SE Community + Cortex Code

The Openflow implementation: SQL-created deployment and runtime, a canvas install per
store, the object definition override, per-store scaling, and the state-reset runbook for
schema changes.

> **Read [README.md](./README.md) first.** The path decision, the Shopify-side app and
> scope work, the API version choice, the shared store registry, the analytics contract,
> the monitoring intent, and the cutover runbook are stated there once and are not
> repeated here.

> **The Shopify connector is a Preview feature.** Openflow Snowflake Deployments are GA;
> the connector is not. Preview features can change behavior and are subject to the
> Snowflake Connector Terms.

---

## What is SQL and what is not

This is the fact that most often surprises a first-time reader, so it comes first.

| Step | Interface | Scriptable |
| --- | --- | --- |
| Deployment, runtime, network rule, EAI, landing schemas, analytics | SQL | Yes |
| Shopify connector install, per-store parameters, controller services, start/stop | NiFi canvas in Snowsight | **No** |

You create the deployment and runtime with `CREATE OPENFLOW DEPLOYMENT` and
`CREATE OPENFLOW RUNTIME`. Each store's Shopify connector, however, is installed from the
connector catalog onto a canvas and configured by right-clicking a process group and
typing parameters. There is no SQL, no infrastructure-as-code, and no documented API for
that step today.

The Shopify connector is **gen 1**. Do not write `CREATE OPENFLOW CONNECTOR` for it — no
definition ID exists. Snowflake is progressively adding SQL definitions for connectors;
re-check the gen 2 catalog at each expiry review. If a Shopify definition ships, phases
4.1 through 4.4 below collapse into one call plus a config file per store, which removes
most of the per-store toil.

**Consequence for "dozens of stores":** one canvas install, one parameter dialog, and one
Shopify dev app per store, plus every store domain in the network rule.
[Phase 5](#phase-5-scale-to-dozens-of-stores) makes this repeatable and reasonably quick.
It does not make it scripted.

---

## Architecture

```text
 Shopify (N stores)                        Snowflake account
 ┌──────────────────┐
 │ store-alpha      │ dev app A ─┐        ┌─────────────────────────────────────────────┐
 │ store-bravo      │ dev app B ─┤        │ OPENFLOW DEPLOYMENT  SHOPIFY_DEPLOYMENT      │
 │ store-charlie    │ dev app C ─┤        │  (SQL) ── Management Services pool           │  ← always-on base cost
 │   ...            │    ...     │ HTTPS  │                                              │
 └──────────────────┘            │  443   │  OPENFLOW RUNTIME  SHOPIFY_RUNTIME (MEDIUM)  │
   Admin GraphQL API             ├───────▶│   EAI ── network rule: every store + GCS     │
   Bulk Operations API           │        │   ┌──────────┐ ┌──────────┐ ┌──────────┐    │
   storage.googleapis.com ───────┘        │   │ Shopify  │ │ Shopify  │ │ Shopify  │ …  │  ← process groups,
   (bulk JSONL results)                   │   │ conn A   │ │ conn B   │ │ conn C   │    │    one per store, canvas-installed
                                          │   └────┬─────┘ └────┬─────┘ └────┬─────┘    │
                                          └────────┼────────────┼────────────┼──────────┘
                                                   │ Snowpipe Streaming + MERGE (SHOPIFY_INGEST_WH)
                                                   ▼            ▼            ▼
                                          SHOPIFY_RAW.STORE_ALPHA   .STORE_BRAVO   .STORE_CHARLIE
                                            ORDERS, ORDER_LINE_ITEMS, ORDER_FULFILLMENTS, FULFILLMENT_ORDERS
                                                   │            │            │
                                                   └────────────┼────────────┘
                                                                ▼  UNION ALL (generated from STORE_REGISTRY)
                                          SHOPIFY_ANALYTICS.CORE  (Dynamic Tables, SHOPIFY_ANALYTICS_WH)
                                            ORDERS_ALL · ORDER_LINE_ITEMS_ALL · ORDER_FULFILLMENTS_ALL
                                            FULFILLMENT_ORDERS_ALL · DAILY_SHOP_ACTIVITY
                                                                ▼
                                          SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY  ← the published contract
```

Four databases, deliberately separate:

| Database | Holds | Who writes |
| --- | --- | --- |
| `SHOPIFY_CONTROL` | Shared registry, baseline, contract, published views | Admin (path-independent) |
| `OPENFLOW_DB` | Runtime, network rule, event table | Admin |
| `SHOPIFY_RAW` | One schema per store | The connector (execute-as role) |
| `SHOPIFY_ANALYTICS` | Dynamic Tables | DT refresh |

---

## Phase 0 — Prerequisites

**Snowflake**

- A non-trial account in an AWS, Azure, or GCP commercial region. Trial accounts need an
  Openflow request through your account team.
- `ACCOUNTADMIN` for the one-time grants in Phase 1. After that, `OPENFLOW_ADMIN`.
- The person who will open the runtime canvas must **not** have `ACCOUNTADMIN` as their
  default role. Phase 1 fixes this; it is a hard login error otherwise.
- Business Critical edition if you require private connectivity (outbound PrivateLink).
- `sql/shared/01_store_registry.sql` and `sql/shared/02_analytics_contract.sql` already
  deployed.

**Shopify**

- Store-admin access to every store, or a Shopify Plus organization admin who can create
  apps across stores. One dev app per store — see
  [Shopify-side preparation](./README.md#shopify-side-preparation).
- A secrets manager for the per-store Client ID/Secret pairs. On this path they are typed
  into the canvas as sensitive parameters and should exist nowhere in version control.

**Team**

- Decide who owns the canvas. Openflow is not a set-and-forget object, and day-two fixes
  happen there rather than in a SQL worksheet.

---

## Phase 1 — Snowflake core, deployment, runtime

Run `sql/openflow/01_core_snowflake.sql` through `04_runtime.sql` in order.

**01 — Core.** Creates `OPENFLOW_ADMIN` and grants the four account privileges a Snowflake
Deployment needs (`CREATE OPENFLOW DEPLOYMENT`, `CREATE COMPUTE POOL`, `CREATE DATABASE`,
`CREATE INTEGRATION`), plus read access to the shared registry. Creates
`OPENFLOW_DB.OPENFLOW_SCHEMA` and a dedicated event table. Sets your default role away
from `ACCOUNTADMIN`.

**02 — Deployment.** A *deployment* is the container for runtimes; Snowflake runs the
control plane. `CREATE OPENFLOW DEPLOYMENT` returns immediately; provisioning takes 5–10
minutes, and `SYSTEM$WAIT_FOR_OPENFLOW_DEPLOYMENT_STATUS` blocks until `ACTIVE`. Limit:
three Snowflake deployments per account. **Billing for the Management Services pool starts
here and does not stop until the deployment is dropped.**

**03 — Execute-as role and EAI.** The *execute-as role* is the identity connectors run as;
no service user or key pair is needed with Snowflake deployments. The *network rule* lists
every host the runtime may reach: `storage.googleapis.com:443` (Shopify returns bulk
results as a signed GCS URL) plus `<store>.myshopify.com:443` per store. The *external
access integration* wraps the rule and attaches to the runtime.

> Use `CREATE ... IF NOT EXISTS` and `ALTER ... SET` for the rule and the EAI. The general
> Openflow docs warn that `CREATE OR REPLACE` *"silently detaches it from every runtime
> that references it."* The Shopify setup page's own example uses `CREATE OR REPLACE`;
> ignore that and follow the safe form in the file.

**04 — Runtime.** A *runtime* hosts flows. `NODE_TYPE` is immutable after creation. This
guide starts at MEDIUM (4 vCPU / 10 GB), 1–2 nodes. Provisioning takes 3–5 minutes.

Verify:

```sql
SHOW OPENFLOW DEPLOYMENTS;
SHOW OPENFLOW RUNTIMES IN SCHEMA OPENFLOW_DB.OPENFLOW_SCHEMA;
```

---

## Phase 2 — Landing zone

Run `sql/openflow/05_store_schemas.sql`. It creates `SHOPIFY_RAW` and, for every store
already in the shared registry, a `SHOPIFY_RAW.<STORE_KEY>` schema granted to the
execute-as role.

Registration and schema creation are separate calls on purpose: the registry is shared
between both paths, the one-schema-per-store layout is not.

```sql
-- Register (shared, path-independent)
CALL SHOPIFY_CONTROL.META.ADD_STORE(
  'STORE_ALPHA', 'store-alpha.myshopify.com', 'merch-analytics@example.com',
  'Alpha Apparel', 'Shopify Plus');

-- Create its landing schema (Openflow-specific)
CALL SHOPIFY_RAW.PUBLIC.CREATE_STORE_SCHEMA('STORE_ALPHA');
```

`CREDENTIAL_OBJECT_FQN` stays NULL on this path: credentials live on the canvas, not as
Snowflake secrets.

Then update the network rule with the full list. The registry emits it paste-ready:

```sql
SELECT VALUE_LIST FROM SHOPIFY_CONTROL.META.NETWORK_RULE_VALUE_LIST;

ALTER NETWORK RULE OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_SHOPIFY_RUNTIME_NETWORK_RULE
  SET VALUE_LIST = ( /* pasted */ );
```

The EAI does not change; it references the rule by name.

### Why one schema per store

The connector creates tables named `ORDERS`, `ORDER_LINE_ITEMS`, … in whatever Destination
Schema you give it. Snowflake documents the merge key as `(ID, SHOP_URL)`, which suggests a
shared table could work, but no documentation states that multiple connector instances
writing the same table is supported. One schema per store stays inside documented
behavior: the blast radius is one store, a state reset drops one store's tables, and the
analytics layer `UNION ALL`s across schemas.

Multi-instance-per-runtime is also not documented for Shopify. Snowflake documents many
CDC connector instances on one runtime and publishes packing heuristics *for CDC*. The
Shopify pages neither prohibit nor describe multiple instances. Nothing says it does not
work, and the `(ID, SHOP_URL)` merge key suggests the design anticipates multiple shops.

---

## Phase 3 — Install and configure the pilot store connector

Do this for **one** store first. Get it to a clean daily sync before Phase 5.

### 3.1 Install

1. In Snowsight, open **Openflow**. Log in as the `OPENFLOW_ADMIN` user (not with an
   `ACCOUNTADMIN` default role).
2. **View more connectors** → find **Shopify** → **Install**.
3. In **Select runtime**, choose `SHOPIFY_RUNTIME` → **Install**. Authenticate to the
   deployment and **Allow**, then authenticate to the runtime. The canvas opens with a
   Shopify process group.
4. **Rename the process group to the store key** (`STORE_ALPHA`) immediately. With dozens
   of identical boxes on one canvas this is the only thing that keeps the canvas legible.

### 3.2 Parameters

Right-click the process group → **Parameters**.

| Parameter | Value | Notes |
| --- | --- | --- |
| Shop Domain | `store-alpha.myshopify.com` | Must exactly match the network rule entry and the registry |
| Shopify Client ID | from secrets manager | |
| Shopify Client Secret | from secrets manager | Stored as sensitive |
| Shopify API Version | **set explicitly; 2026-01 or later** | Do not accept a floating default. Pin every store to the same version. See [Shopify API version](./README.md#shopify-api-version) |
| Objects to Sync | `orders,fulfillmentOrders` | Add `products,productVariants` if wanted |
| Objects to Track for Deletes | *(empty)* | Orders do not emit destroy events; leave off to save API budget |
| Sync Schedule | `24 hours` | Default is `30 min`; the requirement is daily. NiFi scheduling syntax |
| Deletes Schedule | `24 hours` | Irrelevant with no tracked objects, but set it anyway |
| Object Definitions Override | contents of `config/shopify_object_override.json` | See 3.3 |
| Enable Introspection | `false` | Not needed when the override defines every object |
| Snowflake Authentication Strategy | `SNOWFLAKE_MANAGED` | Default; uses the execute-as role |
| Snowflake Role | `OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL` | |
| Destination Database | `SHOPIFY_RAW` | |
| Destination Schema | `STORE_ALPHA` | **Must match the registry `STORE_KEY`** |
| Snowflake Warehouse | `SHOPIFY_INGEST_WH` | |

A Shop Domain that does not match its Destination Schema silently lands one store's data
in another store's schema. Query E in `sql/openflow/07_monitoring.sql` detects exactly
that, by comparing the connector's own `SHOP_URL` against the registry domain.

### 3.3 The object definitions override

`config/shopify_object_override.json` does three things the defaults do not:

- Splits **orders** into `ORDERS`, `ORDER_LINE_ITEMS` (edges connection), and
  `ORDER_FULFILLMENTS` (inline array) — the three tables the analytics layer needs.
- Adds **fulfillmentOrders** → `FULFILLMENT_ORDERS` for the warehouse/3PL view.
- **Promotes** money, timestamp, status, and ID fields into typed columns
  (`NUMBER(38,4)`, `TIMESTAMP_TZ`, …) so the Dynamic Tables never parse JSON.

Validate before pasting — malformed JSON makes the connector refuse to start:

```bash
python3 -c "import json,sys; d=json.load(open('config/shopify_object_override.json')); sys.exit(0 if isinstance(d,list) else 1)" && echo OK
```

Two field-level cautions from the docs: a field that needs a *write* scope to read (for
example `marketingUnsubscribeUrl`) fails the whole object — remove the field rather than
granting the write scope. And a bulk query allows at most **5 connections and 2 levels of
nesting**; this override uses 2 connections on orders.

### 3.4 Start

Right-click empty canvas → **Enable all Controller Services**. Right-click the process
group → **Start**.

The connector submits one Shopify bulk operation per object, polls until Shopify produces
a JSONL file on GCS, downloads it, derives the table schema, creates tables, and loads via
Snowpipe Streaming + MERGE. The `GetShopifyIncremental` processor shows retry/failure
until the bulk load finishes — documented, expected behavior on first run. After that it
switches to incremental on `updatedAt`.

### 3.5 Validate and qualify

```sql
SHOW TABLES IN SCHEMA SHOPIFY_RAW.STORE_ALPHA;
DESCRIBE TABLE SHOPIFY_RAW.STORE_ALPHA.ORDERS;   -- confirm the promoted columns exist

SELECT shop_url,
       COUNT(*)                              AS orders,
       MIN(created_at)                       AS oldest,
       MAX(updated_at)                       AS newest,
       COUNT_IF(__snowflake_is_deleted)      AS soft_deleted
FROM SHOPIFY_RAW.STORE_ALPHA.ORDERS
GROUP BY shop_url;
```

Duplicates immediately after the initial load are expected during the bulk-to-incremental
handoff; the `(ID, SHOP_URL)` merge converges on the first incremental run.

If `oldest` is about 60 days ago and you expected years, that is the `read_orders` window.
Get `read_all_orders` approved, then reset the `orders` object state to re-run the bulk
load.

Record the install and the qualification result:

```sql
UPDATE SHOPIFY_CONTROL.META.STORE_REGISTRY
   SET CONNECTOR_INSTALLED_AT = CURRENT_TIMESTAMP()
 WHERE STORE_KEY = 'STORE_ALPHA';

-- Only after the checks above pass:
UPDATE SHOPIFY_CONTROL.META.STORE_REGISTRY
   SET QUALIFICATION_STATUS = 'PASSED', LAST_QUALIFIED_AT = CURRENT_TIMESTAMP()
 WHERE STORE_KEY = 'STORE_ALPHA';

-- Activation puts the store on the contract surface:
UPDATE SHOPIFY_CONTROL.META.STORE_REGISTRY
   SET IS_ACTIVE = TRUE
 WHERE STORE_KEY = 'STORE_ALPHA' AND QUALIFICATION_STATUS = 'PASSED';
```

Unlike the native path, this path cannot prove a store before its connector runs — there
is no way to extract without starting the flow. Qualification therefore follows the first
successful sync rather than preceding activation.

---

## Phase 4 — Analytics layer

Run `sql/openflow/06_analytics_layer.sql` after at least one store has loaded and
`DESCRIBE TABLE` confirms the promoted columns exist.

| Object | What the analyst gets |
| --- | --- |
| `ORDERS_ALL` | Every order across every active store; `store_key` and `shop_url` as tenant keys, typed money columns, `is_deleted` flag |
| `ORDER_LINE_ITEMS_ALL` | Units, SKU, vendor, price per line; `order_gid` joins to `'gid://shopify/Order/' \|\| order_id` |
| `ORDER_FULFILLMENTS_ALL` | Shipments: status, created/delivered timestamps, tracking |
| `FULFILLMENT_ORDERS_ALL` | Warehouse/3PL assignments and deadlines |
| `DAILY_SHOP_ACTIVITY` | [The contract](./README.md#the-one-analytics-contract) |
| `SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY` | The published contract surface BI reads |
| `SHOPIFY_CONTROL.META.V_STORE_FRESHNESS` | The published ops surface shared monitoring reads |

Design notes:

- The `*_ALL` tables are **generated** by `REBUILD_ANALYTICS_DTS()` from the registry,
  because the set of store schemas changes. `DAILY_SHOP_ACTIVITY` is hand-written: it
  reads the `*_ALL` tables, which already carry every store.
- `TARGET_LAG = '24 hours'` on `ORDERS_ALL` matches the connector's daily sync; a tighter
  lag just burns credits refreshing unchanged data. Downstream tables use `DOWNSTREAM`.
- Soft deletes are **filtered**, never dropped. The connector never physically deletes.
- Verify the contract after every rebuild:

```sql
SELECT COUNT_IF(STATUS <> 'OK') AS CONTRACT_VIOLATIONS
FROM SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE;
```

Deactivating a store: set `IS_ACTIVE = FALSE`, stop its process group on the canvas, and
re-run `REBUILD_ANALYTICS_DTS()`. Its schema and history stay.

---

## Phase 5 — Scale to dozens of stores

This is a **runbook**, not a script. Each store is roughly 20 minutes of clicking once you
have done three. Do them in batches of five and validate between batches.

### Per-store checklist

| # | Step | Where |
| --- | --- | --- |
| 1 | Create, release, install the Shopify dev app; store Client ID/Secret | Shopify Dev Dashboard |
| 2 | `CALL SHOPIFY_CONTROL.META.ADD_STORE(...)` | Snowsight |
| 3 | `CALL SHOPIFY_RAW.PUBLIC.CREATE_STORE_SCHEMA(...)` | Snowsight |
| 4 | `ALTER NETWORK RULE ... SET VALUE_LIST` with the full list from `NETWORK_RULE_VALUE_LIST` | Snowsight |
| 5 | Install the Shopify connector onto `SHOPIFY_RUNTIME`; rename the process group to `<STORE_KEY>` | Canvas |
| 6 | Set parameters (as 3.2, changing Shop Domain, credentials, Destination Schema) | Canvas → Parameters |
| 7 | Enable controller services (once per canvas, harmless to repeat) → Start | Canvas |
| 8 | Validate tables and row counts; set `CONNECTOR_INSTALLED_AT`, then qualification status, then `IS_ACTIVE` | Snowsight |
| 9 | After the batch: `CALL SHOPIFY_ANALYTICS.CORE.REBUILD_ANALYTICS_DTS('24 hours')` | Snowsight |

Step 9 is why the analytics layer is generated: each rebuild replaces the `*_ALL` Dynamic
Tables with a `UNION ALL` over every active store. `DAILY_SHOP_ACTIVITY` uses
`TARGET_LAG = DOWNSTREAM` and follows automatically.

Steps 1, 5, 6, and 7 have no SQL or API today. That is the honest per-store cost of this
path.

### Sizing and when to split runtimes

Facts: MEDIUM is 4 vCPU / 10 GB; you cannot resize; nodes 1–50; each runtime is its own
blast radius; the maximum is 100 runtimes per deployment. Snowflake's CDC heuristic is 5–8
connectors per MEDIUM. There is **no** published Shopify heuristic, and a daily
bulk-plus-incremental Shopify flow is much lighter than a CDC stream.

Judgment: on a daily sync a MEDIUM runtime will very likely hold more than 8 Shopify
process groups. Measure rather than assume. After each batch of five, check runtime CPU
and memory in the event table and queue depth on the canvas. Add a second runtime
(`SHOPIFY_RUNTIME_02`, same execute-as role, same EAI) when:

- you see sustained CPU pressure or growing queues, or
- you want a smaller blast radius, for example a runtime per brand or region, or
- a state reset on one store's bulk load starves the others.

Two runtimes on one deployment is normal.

### Naming discipline

- Process group name = `STORE_KEY` = Destination Schema. One word, three places.
- Shopify app name = `snowflake-shopify-<store_key>`.
- Never rename the connector's built-in parameter contexts; the CDC docs warn that
  renaming breaks future connector version upgrades. Renaming the *process group* is safe.

---

## Operate

`sql/openflow/07_monitoring.sql` holds the Openflow-specific queries; freshness, registry
hygiene, contract conformance, and reconciliation are in `sql/shared/03_monitoring.sql`
and are identical on both paths.

**Cost.** Query A1 splits `OPENFLOW_COMPUTE_SNOWFLAKE` credits into the management floor
(pool named like `OPENFLOW_CONTROL_POOL…`) and runtime pools. A2 adds Snowpipe Streaming
and the two warehouses. There is no per-store attribution on this path.

**Errors.** Query B2 classifies event-table errors against documented signatures:

| Signature | Cause | Fix |
| --- | --- | --- |
| `UnknownHostException: <store>.myshopify.com` | EAI missing or not granted | `03_execute_as_role_eai.sql` |
| `UnresolvedAddressException` / `storage.googleapis.com` | GCS host missing from the network rule | Add `storage.googleapis.com:443` |
| HTTP 401 `Invalid API key or access token` | App uninstalled, unreleased, or wrong credentials | Reinstall the app, restart the connector |
| `Access denied for <object> field` | Missing read scope | Add the scope, release a new version, reinstall |
| `This app is not approved to access the <Object>` | Protected customer data | Shopify access request |
| `Invalid search field` | `incrementalField` not filterable | `supportsIncremental=false`, `refreshStrategy=FULL_PERIODIC` |
| `first cannot exceed 250` | `pageSize` > 250 | Fix the override JSON |
| Object Registry service INVALID | Malformed override JSON | Validate with the python one-liner |
| Bulk operation already in progress | **Your app's** concurrent bulk query slots are all in flight for that shop | On 2026-01 and later each app gets **five** concurrent bulk query operations per shop (earlier versions: one of each type). The limit is per *app*, so another vendor's integration on the same store does not consume your slots. List your own in-flight operations with the `bulkOperations` query, then back off and retry |

**Incremental child cap.** Incremental runs fetch at most 250 line items per order. An
order with more than 250 line items created *after* the initial bulk load will be
truncated. Rare for retail; real for wholesale. The bulk load is not subject to the cap.

---

## Schema-change runbook (state reset)

There is **no schema evolution**. When Shopify adds or removes a field on an object the
connector will not adapt, and this is a documented limitation.

Per store, per changed object:

1. Stop the store's process group on the canvas.
2. Disable its controller services.
3. Open **Shopify State Service → View state** and delete the object's entry.
4. `DROP TABLE SHOPIFY_RAW.<STORE_KEY>.<TABLE>;`
5. Update `config/shopify_object_override.json` and re-paste it into the parameters.
6. Re-enable controller services and **Start**. The connector re-runs the bulk load for
   that object.
7. `CALL SHOPIFY_ANALYTICS.CORE.REBUILD_ANALYTICS_DTS('24 hours');`
8. Re-check the contract:
   `SELECT COUNT_IF(STATUS <> 'OK') FROM SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE;`

Yes, per store. With dozens of stores this is the single largest operational risk on this
path, and surviving one state reset without manual data repair is a cutover gate — see
[Cutover runbook](./README.md#cutover-runbook).

Adding a new object type (for example products) follows the same shape: add the scope in
Shopify and **reinstall** the app, append an entry to the override JSON, add the object to
**Objects to Sync** per store, extend `REBUILD_ANALYTICS_DTS()` with a matching
`EXECUTE IMMEDIATE`, then rebuild.

---

## Teardown

`sql/openflow/08_teardown.sql`, in dependency order. Stop the connector process groups on
the canvas **first**, or the runtime may still be mid-MERGE when the tables disappear.

Dropping the deployment is what stops the Management Services pool and ends the always-on
cost floor. Nothing else does — suspending the runtime only scales its own pool to zero.

The teardown deliberately leaves `SHOPIFY_CONTROL` in place, because the registry, the
reconciliation baseline, and the contract survive a migration to the native path.

Uninstall the Shopify dev app in each store's Dev Dashboard separately; Snowflake cannot
revoke Shopify credentials.
