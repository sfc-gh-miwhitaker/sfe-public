![Guide](https://img.shields.io/badge/type-guide-blue)
![No Deploy](https://img.shields.io/badge/deploy-none-inactive)
![Expires](https://img.shields.io/badge/expires-2026--12--21-yellow)
![Status](https://img.shields.io/badge/status-ACTIVE-brightgreen)

# Dozens of Shopify Stores into Snowflake

How to land daily order, line-item, shipment, and fulfillment data from many Shopify
stores into Snowflake, and consolidate it into one cross-store analytics model. Two
implementation paths are documented in full: the **Openflow Shopify connector**, and a
**native Bulk API pipeline operated through CoCo Desktop**. They produce the identical
analytics contract, so the choice is about operating model and cost shape, not about the
numbers you get out.

**Audience:** Snowflake admins and data engineers evaluating or replacing a third-party
Shopify ELT contract, plus the analytics owner who will consume the result.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-09-21 | **Expires:** 2026-12-21 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Start Here

**The question this guide answers:** "We have dozens of Shopify stores, our ELT vendor
contract is a problem, and we want daily sales and shipment data in Snowflake. What are
our options inside Snowflake, and which should we pick?"

Read [Choose a path](#choose-a-path) first — it is the most valuable section here. Then:

| Step | Where | Path |
| --- | --- | --- |
| 1 | [Choose a path](#choose-a-path) | both |
| 2 | [Shopify-side preparation](#shopify-side-preparation) | both — identical work |
| 3 | [The shared store registry](#the-shared-store-registry) → `sql/shared/01_store_registry.sql` | both |
| 4 | [The one analytics contract](#the-one-analytics-contract) → `sql/shared/02_analytics_contract.sql` | both |
| 5 | **[path-openflow.md](./path-openflow.md)** or **[path-native-coco.md](./path-native-coco.md)** | pick one |
| 6 | [Monitoring intent](#monitoring-intent) → `sql/shared/03_monitoring.sql` | both |
| 7 | [Cutover runbook](#cutover-runbook) | both |

Steps 2, 3, 4, 6, and 7 are path-independent and are stated once, here. Nothing in them
changes if you switch paths later, which is the point: the registry, the contract, the
reconciliation baseline, and the published view names are shared objects.

### The options, honestly

| Option | What it is | Who runs it | Fit for "dozens of stores, daily" |
| --- | --- | --- | --- |
| **Managed ELT** (Fivetran, Airbyte Cloud, Stitch, Estuary, etc.) | SaaS connector; add a store, it appears in Snowflake | Vendor | Best operational fit; cost scales per connector or row and contract terms vary |
| **Openflow Shopify connector** ([path-openflow.md](./path-openflow.md)) | Snowflake-hosted Apache NiFi runtime with a prebuilt Shopify flow | You, inside Snowflake | Works; per-store setup is manual today; billed as Snowflake credits with an always-on floor |
| **Native Bulk API pipeline** ([path-native-coco.md](./path-native-coco.md)) | Python stored procedure calls Shopify's Bulk Operations API, lands JSONL on an internal stage, COPY, Dynamic Tables | You, in Snowflake compute | Cheapest at scale, fully scriptable for N stores, per-store cost attribution; you own the code and the API version |
| **Shopify-side export apps** to a bucket | Third-party Shopify apps push CSV/JSON exports on a schedule | App vendor + Snowpipe | Simple but shallow (no incremental, weak on fulfillments); fine for tiny stores |
| **Marketplace / partner Native Apps** | Search the Snowflake Marketplace for Shopify connectors | Partner | Availability changes; check the Marketplace before deciding |

This guide covers rows 2 and 3 in full.

---

## Choose a path

Both paths land the same four Shopify objects and publish the same 14-column contract.
Everything below is a real difference, not a preference.

| Concern | Openflow connector | Native Bulk API + CoCo |
| --- | --- | --- |
| **Product status** | Shopify connector is **Preview**. Openflow Snowflake Deployments are GA, the connector is not. Subject to the Snowflake Connector Terms and to behavior changes. | All components GA: Python procedures, external access, secrets, tasks, Dynamic Tables. |
| **Who maintains the extraction logic** | Snowflake. You configure it. | You. The GraphQL query, the API version, and the JSONL contract are yours. |
| **Store onboarding** | One canvas install and one parameter dialog per store. No SQL, no API, no infrastructure-as-code for that step. | Add metadata to `config/stores.json`, regenerate bindings, qualify. Scriptable. |
| **Idle cost** | A Management Services compute pool (one `CPU_X64_S` node) starts with the deployment and bills continuously, with zero runtimes running. Only `DROP OPENFLOW DEPLOYMENT` stops it. | None. The task and warehouse run only during the daily pull. |
| **Cost attribution** | Per compute pool, never per store. `OPENFLOW_USAGE_HISTORY` covers BYOC only; Snowflake deployments give you pool-level credits in `METERING_HISTORY`. For per-store cost, put each store on its own runtime or accept an allocation. | Per store, via `QUERY_TAG` and `QUERY_ATTRIBUTION_HISTORY`. |
| **Sizing guidance** | `NODE_TYPE` is immutable after creation. Snowflake publishes packing heuristics for **CDC connectors only** (MEDIUM ~5–8 connectors). There is **no** published heuristic for this workload, and a daily Shopify sync is far lighter than a CDC stream. Sizing is something you measure, not look up. | Warehouse size is mutable, and an XSMALL is sufficient for the pull. No packing question exists. |
| **Secrets** | Sensitive connector parameters, typed into the canvas. | Snowflake `SECRET` objects. `DESC SECRET` never returns the value; the procedure reads it through a fixed alias. |
| **Schema changes** | No schema evolution. Reset the object's connector state and drop the table, per store. | Update the GraphQL selection and the typed Dynamic Table, then qualify one store. |
| **Day-two surface** | The NiFi canvas: process groups, controller services, parameter contexts, state resets, bulletins. | SQL, Python, and a run log, correlated by CoCo Desktop. |
| **Qualification before promotion** | Cannot extract without starting the connector, so a store is proven after it starts running. | Can extract and prove one store with the schedule suspended and the store inactive. |

### When Openflow wins

- You want extraction logic maintained by Snowflake rather than by your team, and you
  accept Preview status to get that.
- Store count is modest and stable, so per-store canvas setup is a one-time cost.
- The always-on floor is small relative to the ELT bill you are replacing, and nobody
  needs per-store cost attribution.
- You would rather configure a product than review code.

### When the native path wins

- Store count is large or growing, so per-store toil compounds and scripting pays.
- You need per-store cost attribution, or you need zero idle cost.
- You want every component GA.
- You want to prove a store's numbers before it is promoted into production.
- Someone is comfortable owning a GraphQL query and an API version pin — with CoCo
  Desktop as the lifecycle interface, that is review work, not authoring work.

### Readiness realities that belong in the decision

1. **The Shopify connector's Preview status is load-bearing.** It is the single biggest
   input to this decision. Re-check it before committing.
2. **Neither path removes Shopify admin work.** One dev app per store, scope approvals,
   release, and install are Shopify-side on both paths. See
   [Shopify-side preparation](#shopify-side-preparation).
3. **Neither path is "add store, done."** Openflow needs a canvas pass per store; the
   native path needs a binding regeneration and a qualification run per store. The
   second is scriptable; neither is zero.
4. **There is no sizing heuristic for this workload on Openflow.** Snowflake publishes
   packing guidance only for CDC. Measure after each batch of five stores.
5. **Openflow is not auto-enabled in trial accounts.** It needs a request through your
   account team.
6. **Private connectivity requires Business Critical edition** on the Openflow path.
7. **Neither path can satisfy a store that restricts inbound API access by IP.**
   Snowflake does not publish a stable egress IP range for either Openflow Snowflake
   Deployments or external access from stored procedures.

### Decision checklist

| Question | Your answer |
| --- | --- |
| Current ELT monthly cost for Shopify connectors (for comparison) | |
| Number of stores now / in 12 months | |
| Do we accept a Preview connector in this pipeline? | |
| Do we need per-store cost attribution? | |
| Who owns day-two operations, and are they comfortable on a NiFi canvas? | |
| Do we need orders older than 60 days on day one? | |
| Do we need customer PII (needs Shopify approval)? | |
| Is a Snowflake trial account involved? | |

---

## Shopify-side preparation

Identical on both paths. Repeat per store; there is no cross-store shortcut in a standard
Shopify setup.

1. Open the **Shopify Dev Dashboard** for the store. Select **Create app**; name it
   something searchable, for example `snowflake-shopify-<store_key>`.
2. Under **Access**, grant only the read scopes you need:

   | Scope | Unlocks | Needed here |
   | --- | --- | --- |
   | `read_orders` | orders, transactions, fulfillments (last 60 days) | Yes |
   | `read_all_orders` | orders older than 60 days | Only for history; **requires Shopify approval** |
   | `read_merchant_managed_fulfillment_orders` | fulfillment orders | Yes |
   | `read_customers` | customers (**protected customer data — requires a separate Shopify approval**) | **No — omitted from this guide** |

3. Select **Release**, confirm. Then on the app **Overview**, **Install app** →
   **Install** on the store. An unreleased or uninstalled app produces HTTP 401.
4. **Settings » Credentials**: copy the **Client ID** and **Client Secret** into your
   secrets manager. On the native path these become a Snowflake `SECRET`; on the Openflow
   path they are typed into the canvas as sensitive parameters. They belong in version
   control on neither path.
5. If you need history, submit the `read_all_orders` access request now. Approval time is
   Shopify's, not Snowflake's.

> Changing scopes later requires releasing a **new app version and reinstalling** on the
> store. Neither pipeline sees a new scope until you do, and a working credential does
> not imply the token carries the new scope.

**The 60-day window is a Shopify rule, not a pipeline defect.** `read_orders` returns the
last 60 days. Expect reconciliation deltas against an incumbent that already has full
history until `read_all_orders` is approved and you have backfilled.

### Shopify API version

**Pin the version explicitly on both paths. Use 2026-01 or later.** Do not accept a
floating default, and keep every store on the same version.

2026-01 is the floor because of what it changed:

| Change in 2026-01 | Why it matters here |
| --- | --- |
| **Five concurrent bulk query operations per app per shop** (and five bulk mutations). Earlier versions allowed one of each type. | The limit is **per app**, so another vendor's integration on the same store does **not** consume your slots, and a second app on the same store has its own allowance. "Bulk operation already in progress" means *your* app's slots are full, not that someone else is blocking you. |
| Poll with `bulkOperation(id:)`, not `currentBulkOperation` | With five possible in flight, "current" is ambiguous and cannot identify your operation. |
| Object grouping is **OFF by default** for `bulkOperationRunQuery` | Never assume a child record follows its parent in the JSONL. Join children to parents by `__parentId`. Both paths here are order-independent. |
| File uploads up to 100 MB | Raises the ceiling on bulk result handling. |

2026-01 is supported until at least 2027-01-01. The native path pins it in
`sql/native/03_pull_procedure.sql`; the Openflow path sets it as a connector parameter,
whose default may be newer — override it deliberately, and confirm your object override's
fields still exist in whatever version you choose. Roll a version change through
one-store qualification before the fleet.

Also independent of path: a bulk query allows at most **5 connections and 2 levels of
nesting**, and a page size above 250 is rejected.

---

## The shared store registry

`sql/shared/01_store_registry.sql` creates `SHOPIFY_CONTROL.META.STORE_REGISTRY` — the
one place that answers "which stores, owned by whom, live or not." Both paths read it.
Deploy it before any path-specific script.

| Column | Purpose |
| --- | --- |
| `STORE_KEY` | PK. Uppercase `[A-Z0-9_]`. On the Openflow path this is also the destination schema name. |
| `SHOP_DOMAIN` | UNIQUE. `<store>.myshopify.com`. |
| `DISPLAY_NAME` | Human label for reports. |
| `BUSINESS_OWNER` | Who answers "is this store still live?" |
| `SHOPIFY_PLAN` | Affects Shopify API rate limits. |
| `IS_ACTIVE` | Defaults to `FALSE`. Means "in the production pipeline": extract it and include it on the contract surface. |
| `QUALIFICATION_STATUS` | `NOT_RUN` / `PASSED` / `FAILED`. Means "trusted for reporting." |
| `CREDENTIAL_OBJECT_FQN` | Native path only; **NULL on the Openflow path**, which keeps credentials as canvas parameters rather than Snowflake secrets. |
| `CONNECTOR_INSTALLED_AT` | Openflow path: set after the canvas install, so freshness can tell "never installed" from "installed but broken." |
| `LAST_QUALIFIED_AT`, `REGISTERED_AT` | Audit. |

`ADD_STORE()` validates and registers. It deliberately does **not** activate: activation
is a separate explicit statement after qualification evidence has been reviewed.

### Store lifecycle

The two flags are independent on purpose, and this sequence is the same on both paths.

| State | `IS_ACTIVE` | `QUALIFICATION_STATUS` | What is true |
| --- | --- | --- | --- |
| Registered | `FALSE` | `NOT_RUN` | Known to the registry; nothing extracts it |
| Qualified | `FALSE` | `PASSED` | Extraction proven for one store. Native path reaches this with the schedule suspended; the Openflow path reaches it only after its connector has run |
| Active | `TRUE` | `PASSED` | Extracting daily and visible on the contract surface. The incumbent is still authoritative for reports |
| Cut over | `TRUE` | `PASSED` | Reconciled for three or more daily cycles; reports repointed |

`sql/shared/03_monitoring.sql` query B flags every disagreement between these two flags,
including a store that went active without passing.

---

## The one analytics contract

Both paths publish **`SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY`** with exactly these
columns. This table is the definition; the two SQL implementations conform to it. Query
the published view rather than a path-specific Dynamic Table, so switching paths does not
touch a single downstream report.

**Grain: one row per `(STORE_KEY, ACTIVITY_DATE, CURRENCY_CODE)`.** `SHOP_URL` is an
attribute of `STORE_KEY`, not part of the grain.

| # | Column | Type | Definition |
| --- | --- | --- | --- |
| 1 | `STORE_KEY` | TEXT | Registry key. Grain. |
| 2 | `SHOP_URL` | TEXT | `STORE_REGISTRY.SHOP_DOMAIN` for that `STORE_KEY`. Sourced from the registry on both paths so the value is identical. |
| 3 | `ACTIVITY_DATE` | DATE | **UTC** calendar date. Orders bucket on `PROCESSED_AT`; shipments bucket on the fulfillment's `CREATED_AT`. Grain. |
| 4 | `CURRENCY_CODE` | TEXT | Shop presentment currency of the order. Carried, never converted — multi-currency stores need an FX step you own. NULL only for a shipment whose parent order is outside the loaded window. Grain. |
| 5 | `ORDERS_PLACED` | NUMBER | Orders processed on `ACTIVITY_DATE`. Excludes test orders and soft-deleted orders. |
| 6 | `ORDERS_CANCELLED` | NUMBER | Subset of `ORDERS_PLACED` with a non-null `CANCELLED_AT`. Not a separate day bucket — a cancellation counts on the order's date, not the cancellation's. |
| 7 | `UNITS_SOLD` | NUMBER | `SUM` of line-item `QUANTITY` across the orders counted in `ORDERS_PLACED`. |
| 8 | `GROSS_SALES` | NUMBER(38,4) | `SUM` of order `TOTAL_PRICE` (shop money). Shopify's total is **already net of discounts**. |
| 9 | `DISCOUNTS` | NUMBER(38,4) | `SUM` of order `TOTAL_DISCOUNTS`. Reported for visibility; never subtracted again. |
| 10 | `REFUNDS` | NUMBER(38,4) | `SUM` of order `TOTAL_REFUNDED`, attributed to the **order's** date, not the refund's date. |
| 11 | `NET_SALES` | NUMBER(38,4) | **`GROSS_SALES - REFUNDS`.** Discounts are not subtracted, per column 8. |
| 12 | `SHIPMENTS_CREATED` | NUMBER | Fulfillments created on `ACTIVITY_DATE`, any status. |
| 13 | `SHIPMENTS_SUCCESS` | NUMBER | Subset with `STATUS = 'SUCCESS'`. |
| 14 | `SHIPMENTS_DELIVERED` | NUMBER | Subset with a non-null `DELIVERED_AT`. |

Contract rules that are easy to get wrong, and are enforced in both implementations:

- **Test orders are excluded** everywhere, including shipments whose parent is a test
  order. Soft-deleted rows are filtered, never physically deleted.
- **Dates are UTC.** Expect a small, explainable delta against an incumbent that buckets
  in a store's local timezone. This is the most common reconciliation difference.
- **A day with shipments but no orders is a real row.** Orders placed Monday ship
  Wednesday; if Wednesday had no new orders, Wednesday still has shipment counts. Both
  implementations `FULL OUTER JOIN` the order and shipment day frames to preserve it. A
  `LEFT JOIN` from orders silently deletes those days, which is a data-loss defect, not a
  simplification.
- **`CURRENCY_CODE` is in every join predicate.** Omitting it fans a single shipment row
  out across every currency row of a multi-currency store and multiplies the counts.
- **All measures are `0`, never NULL.** A row exists only when there was order or
  shipment activity, so "no orders" genuinely means zero.

`sql/shared/02_analytics_contract.sql` encodes this list as data and creates
`V_CONTRACT_CONFORMANCE`, so a drifting implementation fails a query instead of quietly
producing a different table:

```sql
SELECT COUNT_IF(STATUS <> 'OK') AS CONTRACT_VIOLATIONS
FROM SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE;
```

### Why the two implementations differ in structure

The output is identical; the SQL cannot be. This is a genuine consequence of how each
path lands data, not duplicated effort.

| | Openflow path | Native path |
| --- | --- | --- |
| Raw layout | One schema per store, created by the connector | One `STORE_KEY`-partitioned VARIANT table |
| Analytics SQL | **Generated**: `REBUILD_ANALYTICS_DTS()` emits a `UNION ALL` across every active store's schema, re-run whenever the store set changes | **Static**: `CREATE OR ALTER` Dynamic Tables over the one raw table; adding a store changes no SQL |
| Parent/child join | `__parent_id` promoted column vs `'gid://shopify/Order/' \|\| order_id` | `RECORD:__parentId` vs `RECORD:id`, both already GIDs |
| File | `sql/openflow/06_analytics_layer.sql` | `sql/native/05_analytics_layer.sql` |

---

## Monitoring intent

`sql/shared/03_monitoring.sql` holds everything that is identical on both paths, because
it reads only the registry and the two published views:

| Query | Answers |
| --- | --- |
| A | Per-store freshness, labelled `OK` / `LATE` / `STALE` / `NEVER LOADED`. `NEVER LOADED` is separated deliberately: it has a different fix from `STALE` |
| B | Registry hygiene: active without qualification, qualified but never promoted, qualification older than 90 days |
| C | Contract conformance |
| D | Cutover reconciliation against the incumbent baseline |
| E | Grain smoke test. Any row returned means an implementation fans out and the numbers cannot be trusted |

Path-specific monitoring sits beside its implementation, because these have no
counterpart on the other path:

- `sql/openflow/07_monitoring.sql` — credits split into the management floor versus
  runtime pools, the event-table error classifier, ingestion-warehouse MERGE volume, and
  a check for a connector parameterized with the wrong shop for its destination schema.
- `sql/native/06_monitoring.sql` — run log health, zero-lag task history, **per-store**
  credit attribution, qualification evidence, stage inventory, and a failure classifier.

Put the cost query on a weekly schedule and compare it to the ELT bill you are replacing.
That comparison is the entire justification for this project, and it is the one number
most migrations forget to record.

---

## Cutover runbook

Path-independent. Do not turn the incumbent off on day one.

1. **Qualify one store** while the incumbent stays live. On the native path this happens
   with the schedule suspended and the store inactive. On the Openflow path the connector
   must run first, so qualification follows its first successful sync.
2. **Load the incumbent's daily numbers** into
   `SHOPIFY_CONTROL.META.RECONCILIATION_BASELINE` (`STORE_KEY`, `ACTIVITY_DATE`,
   `SOURCE_NAME`, `ORDER_COUNT`, `GROSS_SALES`, `CURRENCY_CODE`).
3. **Reconcile at least three daily cycles per store**: order count, gross sales,
   refunds, and fulfillment count by store, date, and currency. Use query D in
   `sql/shared/03_monitoring.sql`. Expect explainable deltas from UTC bucketing and from
   the 60-day window until `read_all_orders` is approved. An unexplained delta is a stop.
4. **Repoint one downstream report** at `SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY` and
   get its owner's acceptance in writing.
5. **Cut over store by store**, in batches of five, not all at once. Each store qualifies
   independently. Keep the incumbent connector for a store until its owner signs off.
6. **Only cancel the incumbent contract for a store** after the new path has survived, for
   that store, both **a state reset or credential rotation** and **an API version bump**,
   without manual data repair.

If step 6 sounds like a long time, it is. That is the real cost of moving off a managed
service, and it belongs in the decision, not in the retrospective.

---

## Files

| Path | Purpose | Used by |
| --- | --- | --- |
| `sql/shared/01_store_registry.sql` | `SHOPIFY_CONTROL`, `STORE_REGISTRY`, `ADD_STORE()`, reconciliation baseline, network-rule helper view | both |
| `sql/shared/02_analytics_contract.sql` | Contract as data + `V_CONTRACT_CONFORMANCE` | both |
| `sql/shared/03_monitoring.sql` | Freshness, registry hygiene, conformance, reconciliation, grain test | both |
| `sql/openflow/01_core_snowflake.sql` | `OPENFLOW_ADMIN`, account grants, `OPENFLOW_DB`, event table, default-role fix | Openflow |
| `sql/openflow/02_deployment.sql` | `CREATE OPENFLOW DEPLOYMENT` + wait | Openflow |
| `sql/openflow/03_execute_as_role_eai.sql` | Execute-as role, ingest warehouse, multi-store network rule, EAI | Openflow |
| `sql/openflow/04_runtime.sql` | `CREATE OPENFLOW RUNTIME` MEDIUM + wait | Openflow |
| `sql/openflow/05_store_schemas.sql` | Per-store landing schemas, driven by the shared registry | Openflow |
| `sql/openflow/06_analytics_layer.sql` | `REBUILD_ANALYTICS_DTS()`, `DAILY_SHOP_ACTIVITY`, published views, analyst role | Openflow |
| `sql/openflow/07_monitoring.sql` | Cost by pool, event-table classifier, shop/schema mismatch | Openflow |
| `sql/openflow/08_teardown.sql` | Dependency-ordered removal | Openflow |
| `config/shopify_object_override.json` | Connector override: orders → 3 tables + fulfillment orders, typed promoted columns | Openflow |
| `sql/native/01_landing.sql` | Pipeline role, warehouse, stage, run log, qualification evidence, raw VARIANT table | native |
| `sql/native/02_network_secrets.sql` | Wildcard network rule and the interactive secret pattern | native |
| `sql/native/03_pull_procedure.sql` | Token, bulk operation, polling, JSONL, `put_stream`, COPY, logging, all-store loop, `QUALIFY_STORE` | native |
| `sql/native/04_schedule.sql` | Daily task, intentionally suspended | native |
| `sql/native/05_analytics_layer.sql` | Typed Dynamic Tables, `DAILY_SHOP_ACTIVITY`, published views | native |
| `sql/native/06_monitoring.sql` | Health, task history, per-store cost, stage inventory, failure classifier | native |
| `sql/native/07_teardown.sql` | Dependency-ordered removal | native |
| `config/stores.example.json` | Non-secret source of truth for generated bindings | native |
| `tools/generate_store_bindings.py` | Validates stores; generates EAI, grants, registry MERGE, procedure bindings | native |
| `coco/BUILD_PLAYBOOK.md` | The gate sequence and pilot command — defined once, here | native |
| `coco/TROUBLESHOOTING_PLAYBOOK.md` | Boundary-first incident investigation | native |
| `coco/MAINTENANCE_PLAYBOOK.md` | Add store/object, backfill, rotate, pause, API upgrade, path switch | native |
| `coco/automation_*.md`, `coco/create_automations.sh` | Read-only daily, weekly, monthly supervision | native |

SQL marked `-- syntax from docs, not executed` contains Openflow DDL that can only run in
an Openflow-enabled account. The reconciled `DAILY_SHOP_ACTIVITY` join logic was executed
against Snowflake on the created date using synthetic rows, which confirmed that
shipment-only days survive, that the currency grain does not fan out, and that the
`GROUP BY` uses expressions rather than aliases.

---

## Related Guides

- [About the Openflow Connector for Shopify](https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/about)
- [Openflow Snowflake Deployment cost and scaling](https://docs.snowflake.com/en/user-guide/data-integration/openflow/cost-spcs)
- [Snowflake external network access](https://docs.snowflake.com/en/developer-guide/external-network-access/creating-using-external-network-access)
- [Dynamic Tables overview](https://docs.snowflake.com/en/user-guide/dynamic-tables/overview)
- [CoCo Desktop](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop)
- [Shopify bulk query operations](https://shopify.dev/docs/api/usage/bulk-operations/queries)
- [Shopify access scopes](https://shopify.dev/docs/api/usage/access-scopes)
- [Shopify protected customer data](https://shopify.dev/docs/apps/launch/protected-customer-data)

---

## External References

Snowflake documentation (verified 2026-09-21):

- Shopify connector — about: https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/about
- Shopify connector — setup: https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/setup
- Shopify connector — object definition overrides: https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/object-definitions
- Shopify connector — maintain (state reset): https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/maintain
- Shopify connector — troubleshoot: https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/shopify/troubleshoot
- Openflow deployment options: https://docs.snowflake.com/en/user-guide/data-integration/openflow/gen2/openflow-generations
- Connectors available via the SQL setup wizard: https://docs.snowflake.com/en/user-guide/data-integration/openflow/gen2/setup-connector-wizard
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
- External access setup: https://docs.snowflake.com/en/developer-guide/external-network-access/creating-using-external-network-access
- External access best practices: https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-best-practices
- CREATE SECRET: https://docs.snowflake.com/en/sql-reference/sql/create-secret
- DESC SECRET: https://docs.snowflake.com/en/sql-reference/sql/desc-secret
- Python stored procedure limitations: https://docs.snowflake.com/en/developer-guide/stored-procedure/python/procedure-python-limitations
- Snowpark `put_stream`: https://docs.snowflake.com/en/developer-guide/snowpark/reference/python/latest/snowpark/api/snowflake.snowpark.FileOperation.put_stream
- Snowflake Tasks: https://docs.snowflake.com/en/user-guide/tasks-intro
- Dynamic Tables: https://docs.snowflake.com/en/user-guide/dynamic-tables/overview
- CoCo Desktop: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop
- CoCo automations: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-automations
- CoCo cloud sandbox: https://docs.snowflake.com/en/user-guide/cortex-code/cloud-sandbox

Shopify documentation (verified 2026-09-21):

- Bulk query operations: https://shopify.dev/docs/api/usage/bulk-operations/queries
- Access scopes: https://shopify.dev/docs/api/usage/access-scopes
- Protected customer data: https://shopify.dev/docs/apps/launch/protected-customer-data
- Client credentials grant: https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens/client-credentials-grant
- API versioning and release notes: https://shopify.dev/docs/api/usage/versioning
