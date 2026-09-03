![Guide](https://img.shields.io/badge/type-guide-blue)
![No Deploy](https://img.shields.io/badge/deploy-none-inactive)
![Expires](https://img.shields.io/badge/expires-2026--12--03-yellow)
![Status](https://img.shields.io/badge/status-ACTIVE-brightgreen)

# Dozens of Shopify Stores into Snowflake with Openflow

How to land daily order, line-item, shipment, and fulfillment data from many Shopify
stores into Snowflake using Snowflake Openflow (Snowflake Deployment), then consolidate
it into one cross-store analytics model with Dynamic Tables. Written for a Snowflake
administrator who has never touched Openflow and is evaluating it as a replacement for
a third-party ELT contract.

**Audience:** Snowflake admins and data engineers evaluating or standing up Openflow
for SaaS ingestion; the analytics owner who will consume the result.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-09-03 | **Expires:** 2026-12-03 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Start Here

**The question this guide answers:** "We have dozens of Shopify stores, our ELT vendor
contract is a problem, and we want a cheaper way to get daily sales and shipment data
into Snowflake. Is Openflow the answer?"

Short version: **Openflow can do this, and this guide shows exactly how.** It is also
not a drop-in replacement for a managed ELT service, and the multi-store part is more
manual than a first-time reader will expect. Read [Before you commit](#before-you-commit)
before Phase 1. That section is the most valuable part of this document.

### Options people actually use for Shopify to Snowflake

| Option | What it is | Who runs it | Fit for "dozens of stores, daily" |
|---|---|---|---|
| **Managed ELT** (Fivetran, Airbyte Cloud, Stitch, Estuary, etc.) | SaaS connector; you add a store, it appears in Snowflake | Vendor | Best operational fit; cost scales per connector/row and contract terms vary |
| **Snowflake Openflow, Shopify connector** (this guide) | Snowflake-hosted Apache NiFi runtime with a prebuilt Shopify flow | You, inside Snowflake | Works; per-store setup is manual today; billed as Snowflake credits with an always-on floor |
| **Shopify Bulk API → cloud storage → Snowpipe** | Your own scheduled job calls Shopify's Bulk Operations API, writes JSONL to S3/Azure/GCS, Snowpipe loads it | You, in your own compute | Cheapest at scale and fully scriptable for N stores, but you own the code, auth refresh, and schema handling |
| **Shopify-side export apps** to a bucket | Third-party Shopify apps that push CSV/JSON exports on a schedule | App vendor + Snowpipe | Simple but shallow (no incremental, weak on fulfillments); fine for tiny stores |
| **Marketplace / partner Native Apps** | Search the Snowflake Marketplace for Shopify connectors | Partner | Availability changes; check the Marketplace before deciding |

This guide covers the **Openflow** row. If, after reading the next section, the
Bulk-API-plus-Snowpipe row looks better for your team, that is a legitimate conclusion.

---

## Before you commit

Everything below is verified against Snowflake documentation as of the creation date.
Sources are in [External References](#external-references).

### Facts you need in the decision

1. **The Shopify connector is a Preview feature.** Openflow Snowflake Deployments are GA;
   the Shopify connector itself is not. Preview features can change behavior and are
   subject to the Snowflake Connector Terms.

2. **The Shopify connector is a "gen 1" connector.** Openflow has two generations. Gen 2
   makes deployments, runtimes, and connectors SQL objects (`CREATE OPENFLOW DEPLOYMENT`,
   `CREATE OPENFLOW RUNTIME`, `CREATE OPENFLOW CONNECTOR`). Today, only the PostgreSQL and
   MySQL CDC connectors exist as gen 2 definitions. **Shopify has no gen 2 definition.**
   You can create the deployment and runtime with SQL (this guide does), but each store's
   connector is installed from the catalog onto a NiFi canvas and configured by
   right-clicking a process group and typing parameters. There is no SQL, no
   infrastructure-as-code, and no API documented for this step.

   **Consequence for "dozens of stores":** dozens of canvas installs, dozens of parameter
   dialogs, dozens of Shopify dev apps, and every store domain added to one network rule.
   Phase 5 gives you a runbook to make that repeatable, but it does not make it automatic.

3. **There is a cost floor you cannot turn off.** Creating a deployment starts an Openflow
   Management Services compute pool (one `CPU_X64_S` node). Snowflake docs: it *"continues
   to run and incurs costs, even if there are no runtimes running."* Suspending the runtime
   stops runtime cost; only dropping the deployment stops the floor. On top of that you pay
   for the runtime compute pool while it runs, Snowpipe Streaming ingestion, warehouse time
   for `CREATE TABLE`/`MERGE`, and telemetry ingest into the event table.

4. **You cannot attribute cost per runtime.** `OPENFLOW_USAGE_HISTORY` covers BYOC only.
   For Snowflake deployments you get compute-pool-level credits in `METERING_HISTORY`
   (`SERVICE_TYPE = 'OPENFLOW_COMPUTE_SNOWFLAKE'`). If finance asks "what does store X cost,"
   the honest answer is "we can tell you what the runtime costs."

5. **No schema evolution.** If Shopify adds or removes a field on an object, you reset the
   connector state for that object and drop the table. This is a documented limitation.

6. **The 60-day order window is a Shopify rule, not a connector bug.** `read_orders` returns
   the last 60 days. Full history requires `read_all_orders`, which needs a Shopify access
   request per app. Customer names, addresses, emails, and phones are *protected customer
   data* and need a separate Shopify approval. Budget for these approvals per store.

7. **Multi-instance-per-runtime is not documented for Shopify.** Snowflake documents
   running many CDC connector instances on one runtime and publishes packing heuristics
   (MEDIUM: 5–8 connectors) *for CDC*. The Shopify pages neither prohibit nor describe
   multiple instances. Nothing in the docs says it does not work, and the merge key
   `(ID, SHOP_URL)` suggests the design anticipates multiple shops. This guide uses one
   connector instance per store on a shared runtime with **one destination schema per
   store**, which stays inside documented behavior. Treat sizing as something you measure,
   not something you look up.

8. **You are operating NiFi.** Canvas, process groups, controller services, parameter
   contexts, state resets, bulletins. The Shopify connector hides most of it, but when
   something breaks the fix is on the canvas, not in a SQL worksheet. If your team came to
   Snowflake specifically to avoid running integration infrastructure, notice that this is
   the opposite operating model, even though it lives inside Snowflake.

### When this path tends to work

- You are replacing a tool whose bill is materially higher than the Openflow floor plus
  runtime, so total cost actually drops.
- You start with **one store**, get it stable, and only then scale.
- The incumbent pipeline keeps running through the migration; you cut over store by store
  after reconciling row counts (see [Cutover](#cutover-from-an-existing-elt-tool)).
- Someone on the team is comfortable reading NiFi bulletins and resetting connector state.

### When it tends not to

- The team expected "add store, done" and has no appetite for a per-store runbook.
- Under-consumption: if you already have unused Snowflake credits, "it bills as credits"
  is not a saving — it is spending you were not going to spend.
- You need full order history immediately and have not yet obtained `read_all_orders`.
- Private connectivity is a requirement and you are not on Business Critical edition.

### Decision checklist

Fill this in before Phase 1.

| Question | Your answer |
|---|---|
| Current ELT monthly cost for Shopify connectors | |
| Number of stores now / in 12 months | |
| Do we already have unused Snowflake credits? | |
| Who owns the runtime canvas on-call? | |
| Do we need orders older than 60 days on day one? | |
| Do we need customer PII (needs Shopify approval)? | |
| Is a Snowflake trial account involved? (Openflow is not auto-enabled in trials) | |

---

## Architecture

```
 Shopify (N stores)                        Snowflake account
 ┌──────────────────┐
 │ store-alpha      │ dev app A ─┐        ┌─────────────────────────────────────────────┐
 │ store-bravo      │ dev app B ─┤        │ OPENFLOW DEPLOYMENT  SHOPIFY_DEPLOYMENT      │
 │ store-charlie    │ dev app C ─┤        │  (gen 2, SQL)   ── Management Services pool  │  ← always-on floor
 │   ...            │    ...     │ HTTPS  │                                              │
 └──────────────────┘            │  443   │  OPENFLOW RUNTIME  SHOPIFY_RUNTIME (MEDIUM)  │
   Admin GraphQL API             ├───────▶│   EAI ── network rule: every store + GCS     │
   Bulk Operations API           │        │   ┌──────────┐ ┌──────────┐ ┌──────────┐    │
   storage.googleapis.com ───────┘        │   │ Shopify  │ │ Shopify  │ │ Shopify  │ …  │  ← gen 1 process groups,
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
                                            FULFILLMENT_ORDERS_ALL · DAILY_SHOP_ACTIVITY · STORE_FRESHNESS
```

Three databases, deliberately separate:

| Database | Holds | Who writes |
|---|---|---|
| `OPENFLOW_DB` | Runtime, network rule, event table | Admin |
| `SHOPIFY_RAW` | One schema per store + `META` registry | The connector (execute-as role) |
| `SHOPIFY_ANALYTICS` | Dynamic Tables and views | DT refresh |

---

## Files

| Path | Purpose |
|---|---|
| `sql/01_core_snowflake.sql` | `OPENFLOW_ADMIN` role, account grants, `OPENFLOW_DB`, event table, default-role fix |
| `sql/02_deployment.sql` | `CREATE OPENFLOW DEPLOYMENT` + wait |
| `sql/03_execute_as_role_eai.sql` | Execute-as role, ingestion warehouse, multi-store network rule, EAI |
| `sql/04_runtime.sql` | `CREATE OPENFLOW RUNTIME` MEDIUM + wait |
| `sql/05_store_schemas.sql` | `STORE_REGISTRY`, `ADD_STORE()` procedure, per-store schemas and grants |
| `config/shopify_object_override.json` | Connector parameter: orders → 3 tables + fulfillment orders, typed promoted columns |
| `sql/06_analytics_layer.sql` | `REBUILD_ANALYTICS_DTS()` generator, `DAILY_SHOP_ACTIVITY`, `STORE_FRESHNESS`, analyst role |
| `sql/07_monitoring.sql` | Cost by compute pool, per-store freshness, event-table error classifier, DT health |
| `sql/08_teardown.sql` | Remove everything in dependency order |

SQL files marked `-- syntax from docs, not executed` contain Openflow DDL that can only run
in an Openflow-enabled account. Everything else was compile-checked.

---

## Phase 0 — Prerequisites

**Snowflake**

- A non-trial account in an AWS, Azure, or GCP commercial region. Trial accounts need an
  Openflow request through your account team.
- `ACCOUNTADMIN` for the one-time grants in Phase 1. After that, `OPENFLOW_ADMIN`.
- The person who will open the runtime canvas must **not** have `ACCOUNTADMIN` as their
  default role. Phase 1 fixes this; it is a hard login error otherwise.
- Business Critical edition if you require private connectivity (outbound PrivateLink).

**Shopify**

- Store-admin access to every store, or a Shopify Plus organization admin who can create
  apps across stores. You will create one dev app per store.
- A list of stores: domain (`<name>.myshopify.com`), business owner, plan tier, and rough
  monthly order volume. This becomes `STORE_REGISTRY`.
- A secrets manager (1Password, AWS Secrets Manager, Vault) for the per-store Client
  ID/Secret pairs. They are typed into the canvas as sensitive parameters and should exist
  nowhere in version control.

**Team**

- Decide who owns the canvas. Openflow is not a set-and-forget object.

---

## Phase 1 — Snowflake core, deployment, runtime

Run `sql/01_core_snowflake.sql` through `sql/04_runtime.sql` in order. What each one does,
for a first-timer:

**01 — Core.** Creates `OPENFLOW_ADMIN` and grants the four account privileges gen 2 needs
(`CREATE OPENFLOW DEPLOYMENT`, `CREATE COMPUTE POOL`, `CREATE DATABASE`, `CREATE INTEGRATION`).
Creates `OPENFLOW_DB.OPENFLOW_SCHEMA` for infrastructure objects and a dedicated event table.
Sets your default role away from `ACCOUNTADMIN`.

**02 — Deployment.** A *deployment* is the container for runtimes; Snowflake runs the
control plane. `CREATE OPENFLOW DEPLOYMENT` returns immediately; provisioning takes 5–10
minutes. `SYSTEM$WAIT_FOR_OPENFLOW_DEPLOYMENT_STATUS` blocks until `ACTIVE`. Limit: three
Snowflake deployments per account. **Billing for the Management Services pool starts here.**

**03 — Execute-as role and EAI.** The *execute-as role* is the identity connectors run as;
no service user or key pair is needed with Snowflake deployments. The *network rule* lists
every host the runtime may reach: `storage.googleapis.com:443` (Shopify returns bulk
results as a signed GCS URL) plus `<store>.myshopify.com:443` for each store. The *external
access integration* wraps the rule and is attached to the runtime.

> Use `CREATE ... IF NOT EXISTS` and `ALTER ... SET` for the rule and EAI. The general
> Openflow docs warn that `CREATE OR REPLACE` *"silently detaches it from every runtime that
> references it."* The Shopify setup page's own example uses `CREATE OR REPLACE`; ignore
> that and follow the safe form in `03_execute_as_role_eai.sql`.

**04 — Runtime.** A *runtime* hosts flows. Size is immutable after creation. This guide
starts at MEDIUM (4 vCPU / 10 GB), 1–2 nodes, based on the CDC packing heuristic since no
Shopify guidance exists. Provisioning takes 3–5 minutes.

Verify:

```sql
SHOW OPENFLOW DEPLOYMENTS;
SHOW OPENFLOW RUNTIMES IN SCHEMA OPENFLOW_DB.OPENFLOW_SCHEMA;
```

---

## Phase 2 — Shopify: one dev app per store

Repeat for every store. There is no shortcut across stores in a standard Shopify setup.

1. Open the **Shopify Dev Dashboard** for the store. Select **Create app**; name it
   something searchable (`snowflake-openflow-<store>`).
2. Under **Access**, grant only the read scopes you need:

   | Scope | Unlocks | Needed for this guide |
   |---|---|---|
   | `read_orders` | orders, transactions, fulfillments (last 60 days) | Yes |
   | `read_all_orders` | orders older than 60 days | Only for history; **requires Shopify approval** |
   | `read_merchant_managed_fulfillment_orders` | fulfillment orders | Yes |
   | `read_products` | products, variants, collections | Optional |
   | `read_customers` | customers (**protected customer data — requires approval**) | No — omitted from this guide |
   | `read_inventory` | inventory items, locations | Optional |

3. Select **Release**, confirm. Then on the app **Overview**, **Install app** → **Install**
   on the store. (Unreleased or uninstalled apps produce HTTP 401 in the connector.)
4. **Settings » Credentials**: copy **Client ID** and **Client Secret** into your secrets
   manager under the store's key.
5. If you need history: submit the `read_all_orders` access request now. Approval time
   is Shopify's, not Snowflake's.

> If you later change scopes, you must release a new app version **and reinstall** on the
> store. The connector will not see new scopes until you do.

---

## Phase 3 — Landing zone

Run `sql/05_store_schemas.sql`. It creates `SHOPIFY_RAW`, the `META.STORE_REGISTRY` table,
and an `ADD_STORE()` procedure that registers a store, creates `SHOPIFY_RAW.<STORE_KEY>`,
and grants the execute-as role `USAGE` + `CREATE TABLE` on it.

```sql
CALL SHOPIFY_RAW.META.ADD_STORE('STORE_ALPHA', 'store-alpha.myshopify.com', 'merch-analytics@example.com', 'Alpha Apparel', 'Shopify Plus');
```

Then update the network rule with the full list — the `NETWORK_RULE_VALUE_LIST` view emits
a paste-ready list from the registry:

```sql
SELECT value_list FROM SHOPIFY_RAW.META.NETWORK_RULE_VALUE_LIST;
-- paste into:
ALTER NETWORK RULE OPENFLOW_DB.OPENFLOW_SCHEMA.OPENFLOW_SHOPIFY_RUNTIME_NETWORK_RULE
  SET VALUE_LIST = ( ...pasted... );
```

The EAI does not need to change; it references the rule by name.

---

## Phase 4 — Install and configure the pilot store connector

Do this for **one** store first. Get it to a clean daily sync before Phase 5.

### 4.1 Install

1. In Snowsight, open **Openflow**. Log in as the `OPENFLOW_ADMIN` user (not ACCOUNTADMIN
   default role).
2. **View more connectors** → find **Shopify** → **Install**.
3. In **Select runtime**, choose `SHOPIFY_RUNTIME` → **Install**. Authenticate to the
   deployment and **Allow**; then authenticate to the runtime. Installation takes a few
   minutes. The canvas opens with a Shopify process group.
4. **Rename the process group** to the store key (`STORE_ALPHA`) immediately. With dozens
   of identical boxes on one canvas, this is the only thing that keeps you sane.

### 4.2 Parameters

Right-click the process group → **Parameters**. Set:

| Parameter | Value | Notes |
|---|---|---|
| Shop Domain | `store-alpha.myshopify.com` | Must exactly match the network rule entry |
| Shopify Client ID | from secrets manager | |
| Shopify Client Secret | from secrets manager | Stored as sensitive |
| Shopify API Version | leave default (`2026-04` at time of writing) | Pin all stores to the same version |
| Objects to Sync | `orders,fulfillmentOrders` | Add `products,productVariants` if wanted |
| Objects to Track for Deletes | *(empty)* | Orders do not emit destroy events; leave off to save API budget |
| Sync Schedule | `24 hours` | Default is `30 min`; the requirement is daily. NiFi scheduling syntax |
| Deletes Schedule | `24 hours` | Irrelevant with no tracked objects, but set it anyway |
| Object Definitions Override | contents of `config/shopify_object_override.json` | See 4.3 |
| Enable Introspection | `false` | Not needed when the override defines every object |
| Snowflake Authentication Strategy | `SNOWFLAKE_MANAGED` | Default; uses the execute-as role |
| Snowflake Role | `OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL` | |
| Destination Database | `SHOPIFY_RAW` | |
| Destination Schema | `STORE_ALPHA` | **Must match the registry `store_key`** |
| Snowflake Warehouse | `SHOPIFY_INGEST_WH` | |

### 4.3 The Object Definitions Override

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

Two field-level cautions from the docs: a field that needs a *write* scope to read
(e.g. `marketingUnsubscribeUrl`) fails the whole object — remove it rather than granting
the write scope. And the bulk API allows at most **5 connections and 2 levels of nesting**
per query; the override uses 2 connections on orders.

### 4.4 Start

Right-click an empty area of the canvas → **Enable all Controller Services**. Right-click
the process group → **Start**.

What happens: the connector submits one Shopify **bulk operation** per object, polls until
Shopify produces a JSONL file on GCS, downloads it, derives the table schema from the
response, creates tables, and loads via Snowpipe Streaming + MERGE. The `GetShopifyIncremental`
processor will show retry/failure until the bulk load finishes — this is documented,
expected behavior on first run. After that it switches to incremental on `updatedAt`.

### 4.5 Validate

```sql
SHOW TABLES IN SCHEMA SHOPIFY_RAW.STORE_ALPHA;
DESCRIBE TABLE SHOPIFY_RAW.STORE_ALPHA.ORDERS;        -- confirm promoted columns exist

SELECT shop_url, COUNT(*) AS orders,
       MIN(created_at) AS oldest, MAX(updated_at) AS newest,
       COUNT_IF(__snowflake_is_deleted) AS soft_deleted
FROM SHOPIFY_RAW.STORE_ALPHA.ORDERS
GROUP BY shop_url;
```

Duplicates right after the initial load are expected during the bulk-to-incremental
handoff; the `(ID, SHOP_URL)` merge converges on the first incremental run.

If `oldest` is ~60 days ago and you expected years, that is the `read_orders` window. Get
`read_all_orders` approved, then reset the `orders` object state (Maintain doc) to re-run
the bulk load.

Set `connector_installed_at` in the registry so `STORE_FRESHNESS` can distinguish "never
installed" from "installed but broken":

```sql
UPDATE SHOPIFY_RAW.META.STORE_REGISTRY
   SET connector_installed_at = CURRENT_TIMESTAMP()
 WHERE store_key = 'STORE_ALPHA';
```

---

## Phase 5 — Scale to dozens of stores

This is a **runbook**, not a script. Each store is roughly 20 minutes of clicking once you
have done three. Do them in batches of five and validate between batches.

### Per-store checklist

| # | Step | Where | Artifact |
|---|---|---|---|
| 1 | Create, release, install Shopify dev app; store Client ID/Secret | Shopify Dev Dashboard | secrets-manager entry |
| 2 | `CALL ADD_STORE(...)` | Snowsight | `SHOPIFY_RAW.<STORE_KEY>` |
| 3 | `ALTER NETWORK RULE ... SET VALUE_LIST` (full list from `NETWORK_RULE_VALUE_LIST`) | Snowsight | updated rule |
| 4 | Install Shopify connector onto `SHOPIFY_RUNTIME`; rename process group to `<STORE_KEY>` | Openflow canvas | process group |
| 5 | Set parameters (same as 4.2, change Shop Domain, credentials, Destination Schema) | Canvas → Parameters | |
| 6 | Enable controller services (only needed once per canvas, but harmless) → Start | Canvas | |
| 7 | Validate tables and row counts; `UPDATE STORE_REGISTRY SET connector_installed_at` | Snowsight | |
| 8 | After the batch: `CALL SHOPIFY_RAW.META.REBUILD_ANALYTICS_DTS('24 hours')` | Snowsight | DTs include new stores |

Step 8 is why the analytics layer is generated: each rebuild `CREATE OR REPLACE`s the
`*_ALL` Dynamic Tables with a UNION ALL over every active store. Downstream
`DAILY_SHOP_ACTIVITY` uses `TARGET_LAG = DOWNSTREAM` and follows.

### Sizing and when to split runtimes

Facts: MEDIUM = 4 vCPU / 10 GB; you cannot resize; nodes 1–50; each runtime is its own
blast radius. Snowflake's CDC heuristic is 5–8 connectors per MEDIUM. There is **no**
published Shopify heuristic, and a daily bulk-plus-incremental Shopify flow is much lighter
than a CDC stream.

Judgment: on a daily sync, a MEDIUM runtime will very likely hold more than 8 Shopify
process groups. Measure before assuming. After each batch of five, check runtime CPU and
memory in the event table and look at queue depth on the canvas. Add a second runtime
(`SHOPIFY_RUNTIME_02`, same execute-as role, same EAI) when:

- you see sustained CPU pressure or growing queues, or
- you want a smaller blast radius (e.g. a runtime per brand or region), or
- a state reset on one store's bulk load starves the others.

Two runtimes on one deployment is normal; the max is 100 runtimes per deployment.

### Naming discipline

- Process group name = `STORE_KEY` = Destination Schema. One word, three places.
- Shopify app name = `snowflake-openflow-<store_key>`.
- Never rename the connector's built-in parameter contexts; the CDC docs warn that renaming
  breaks future connector version upgrades. Renaming the *process group* is safe.

### What is still manual, honestly

Steps 1, 4, 5, and 6 have no SQL or API today. If a gen 2 Shopify definition ships, steps
4–6 collapse into `CREATE OPENFLOW CONNECTOR ... FROM DEFINITION` plus a `config.json` per
store with secrets by reference. Check the gen 2 connector catalog at each expiry review;
that change would remove most of the per-store toil.

---

## Phase 6 — Analytics layer

Run `sql/06_analytics_layer.sql` after at least one store has loaded and you have run
`DESCRIBE TABLE` to confirm the promoted columns exist.

| Object | What it gives the analyst |
|---|---|
| `ORDERS_ALL` | Every order across every store, `store_key` + `shop_url` as tenant keys, typed money columns, `is_deleted` flag |
| `ORDER_LINE_ITEMS_ALL` | Units, SKU, vendor, price per line; `order_gid` joins to `'gid://shopify/Order/' \|\| order_id` |
| `ORDER_FULFILLMENTS_ALL` | Shipments: status, created/delivered timestamps, tracking |
| `FULFILLMENT_ORDERS_ALL` | Warehouse/3PL assignments and deadlines |
| `DAILY_SHOP_ACTIVITY` | One row per store per day: orders placed/cancelled, units, gross/net sales, shipments created/success/delivered |
| `STORE_FRESHNESS` | Ops: hours since last update per registered store |

Design notes:

- `TARGET_LAG = '24 hours'` on `ORDERS_ALL` matches the connector's daily sync; a tighter lag
  just burns warehouse credits refreshing unchanged data. Downstream tables use `DOWNSTREAM`.
- Soft deletes are **filtered**, never dropped. The connector never physically deletes rows.
- `IS_TEST` orders are excluded from `DAILY_SHOP_ACTIVITY`.
- Currency is carried, not converted. Multi-currency stores need an FX step you own.
- `SHOPIFY_ANALYST` is a read-only role over `SHOPIFY_ANALYTICS.CORE`.

Deactivating a store: `UPDATE STORE_REGISTRY SET is_active = FALSE`, stop its process
group on the canvas, and re-run `REBUILD_ANALYTICS_DTS()`. Its schema and history stay.

---

## Phase 7 — Operate

`sql/07_monitoring.sql` has the daily queries. The ones that matter most:

**Cost.** Query A1 splits `OPENFLOW_COMPUTE_SNOWFLAKE` credits into the management floor
(pool named `OPENFLOW_CONTROL_POOL…`) and runtime pools. Query A2 adds Snowpipe Streaming
and the two warehouses. Put this on a weekly schedule and compare to the ELT bill you are
replacing — that comparison is the entire justification for this project.

**Freshness.** Query B labels each store `OK` / `LATE` / `STALE` / `NEVER LOADED`.

**Errors.** Query C2 classifies event-table errors against the documented failure
signatures:

| Signature | Cause | Fix |
|---|---|---|
| `UnknownHostException: <store>.myshopify.com` | EAI missing or not granted | `03_execute_as_role_eai.sql` |
| `UnresolvedAddressException` / `storage.googleapis.com` | GCS host missing from network rule | Add `storage.googleapis.com:443` |
| HTTP 401 `Invalid API key or access token` | App uninstalled, unreleased, or wrong credentials | Reinstall app, restart connector |
| `Access denied for <object> field` | Missing read scope | Add scope, release new version, reinstall |
| `This app is not approved to access the <Object>` | Protected customer data | Shopify access request |
| `Invalid search field` | `incrementalField` not filterable | `supportsIncremental=false`, `refreshStrategy=FULL_PERIODIC` |
| `first cannot exceed 250` | `pageSize` > 250 | Fix override JSON |
| Object Registry service INVALID | Malformed override JSON | Validate with the python one-liner |
| Bulk operation already in progress | Another integration on the same shop holds the slot | Wait; Shopify allows one per shop |

**Schema change runbook.** Shopify changes a field → the connector will not adapt. Stop
the process group, disable controller services, open **Shopify State Service → View state**,
delete the object's entry, drop `SHOPIFY_RAW.<STORE>.<TABLE>`, re-enable and start. Then
`REBUILD_ANALYTICS_DTS()`. Repeat per store. Yes, per store.

**Incremental child cap.** Incremental runs fetch at most 250 line items per order. An
order with more than 250 line items created *after* the initial bulk load will be truncated.
Rare for retail; real for wholesale. The bulk load is not subject to the cap.

---

## Cutover from an existing ELT tool

Do not turn the incumbent off on day one.

1. Run both pipelines for at least **three daily cycles** per store.
2. Reconcile per store per day: order count, sum of `TOTAL_PRICE`, fulfillment count.
   Expect small deltas from timezone (this guide uses UTC dates) and from the 60-day window
   until `read_all_orders` is approved.
3. Repoint one downstream report at `SHOPIFY_ANALYTICS.CORE`; confirm with its owner.
4. Cut over store by store, not all at once. Keep the incumbent connector for a store until
   its owner signs off.
5. Only cancel the incumbent contract for a store after its Openflow flow has survived one
   state reset and one Shopify API version bump without manual data repair.

If step 5 sounds like a long time, it is. That is the real cost of moving off a managed
service, and it belongs in the decision, not in the retrospective.

---

## Related Guides

- [About the Openflow Connector for Shopify](https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/about)
- [Openflow generations (gen 1 vs gen 2)](https://docs.snowflake.com/en/user-guide/data-integration/openflow/gen2/openflow-generations)
- [Openflow Snowflake Deployment cost and scaling](https://docs.snowflake.com/en/user-guide/data-integration/openflow/cost-spcs)
- [Dynamic Tables overview](https://docs.snowflake.com/en/user-guide/dynamic-tables/overview)
- [Shopify Bulk Operations API](https://shopify.dev/docs/api/usage/bulk-operations/queries)
- [Shopify access scopes](https://shopify.dev/docs/api/usage/access-scopes)

---

## External References

Snowflake documentation (all verified 2026-09-03):

- Shopify connector — about: https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/about
- Shopify connector — setup: https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/setup
- Shopify connector — object definition overrides: https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/object-definitions
- Shopify connector — maintain (state reset): https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/maintain
- Shopify connector — troubleshoot: https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/troubleshoot
- Openflow generations: https://docs.snowflake.com/en/user-guide/data-integration/openflow/gen2/openflow-generations
- Gen 2 supported connectors (setup wizard): https://docs.snowflake.com/en/user-guide/data-integration/openflow/gen2/setup-connector-wizard
- Gen 2 quickstart: https://docs.snowflake.com/en/user-guide/data-integration/openflow/gen2/quickstart
- Configure connector with SQL (config.json, secrets): https://docs.snowflake.com/en/user-guide/data-integration/openflow/gen2/configure-connector-sql
- Snowflake Deployment task overview: https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-spcs
- Core Snowflake setup: https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-spcs-sf
- Create deployment: https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-spcs-deployment
- Execute-as role and EAI: https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-spcs-create-rr
- About Snowflake Deployments (limitations): https://docs.snowflake.com/en/user-guide/data-integration/openflow/about-spcs
- Cost and scaling (Snowflake deployments): https://docs.snowflake.com/en/user-guide/data-integration/openflow/cost-spcs
- CDC runtime sizing and packing: https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/cdc-runtime-sizing
- CREATE OPENFLOW DEPLOYMENT: https://docs.snowflake.com/en/sql-reference/sql/create-openflow-deployment
- CREATE OPENFLOW RUNTIME: https://docs.snowflake.com/en/sql-reference/sql/create-openflow-runtime
- CREATE OPENFLOW CONNECTOR: https://docs.snowflake.com/en/sql-reference/sql/create-openflow-connector
- Exploring compute cost: https://docs.snowflake.com/en/user-guide/cost-exploring-compute

Shopify documentation:

- Protected customer data: https://shopify.dev/docs/apps/launch/protected-customer-data
- Client credentials grant: https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/client-credentials-grant
