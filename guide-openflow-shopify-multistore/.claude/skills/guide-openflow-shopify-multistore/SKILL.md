---
name: guide-openflow-shopify-multistore
description: >
  Guide for landing dozens of Shopify stores in Snowflake daily with Openflow
  (Snowflake Deployment, gen 2 infra + gen 1 Shopify connector) and a Dynamic Table
  analytics layer. Triggers: openflow shopify, shopify snowflake, multiple shopify
  stores, replace fivetran shopify, openflow connector shopify, shopify orders
  fulfillments snowflake, openflow gen 2 deployment runtime, openflow cost floor.
---

# Guide: Dozens of Shopify Stores into Snowflake with Openflow

## Purpose

Reference guide for a Snowflake admin new to Openflow who must ingest daily order,
line-item, shipment, and fulfillment data from many Shopify stores as a replacement for a
third-party ELT contract. Covers the honest decision (Preview connector, gen 1 canvas
setup per store, always-on cost floor), SQL-created deployment and runtime, a per-store
runbook, a registry-driven landing zone, and generated cross-store Dynamic Tables.

## Architecture

```
N Shopify stores (one dev app each, read_orders + read_merchant_managed_fulfillment_orders)
  → OPENFLOW DEPLOYMENT SHOPIFY_DEPLOYMENT (gen 2, SQL)   ← Management Services pool, always-on
  → OPENFLOW RUNTIME SHOPIFY_RUNTIME (MEDIUM, 1-2 nodes)
      EAI → network rule listing every <store>.myshopify.com:443 + storage.googleapis.com:443
      N × Shopify connector process groups (gen 1, canvas-installed, one per store)
  → SHOPIFY_RAW.<STORE_KEY>.{ORDERS, ORDER_LINE_ITEMS, ORDER_FULFILLMENTS, FULFILLMENT_ORDERS}
  → SHOPIFY_ANALYTICS.CORE.*_ALL Dynamic Tables (UNION ALL generated from STORE_REGISTRY)
  → DAILY_SHOP_ACTIVITY (DOWNSTREAM), STORE_FRESHNESS view
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Full guide: options table, "Before you commit", 7 phases, cutover, references |
| `ELI5.md` | Plain-language companion |
| `sql/01_core_snowflake.sql` | OPENFLOW_ADMIN, account grants, OPENFLOW_DB, event table, default-role fix |
| `sql/02_deployment.sql` | CREATE OPENFLOW DEPLOYMENT + wait (syntax from docs, not executed) |
| `sql/03_execute_as_role_eai.sql` | Execute-as role, SHOPIFY_INGEST_WH, multi-store network rule, EAI |
| `sql/04_runtime.sql` | CREATE OPENFLOW RUNTIME MEDIUM (syntax from docs, not executed) |
| `sql/05_store_schemas.sql` | STORE_REGISTRY, ADD_STORE(), NETWORK_RULE_VALUE_LIST view |
| `config/shopify_object_override.json` | Connector override: orders → 3 tables, fulfillmentOrders, promoted typed columns |
| `sql/06_analytics_layer.sql` | REBUILD_ANALYTICS_DTS(), DAILY_SHOP_ACTIVITY, STORE_FRESHNESS, SHOPIFY_ANALYST |
| `sql/07_monitoring.sql` | Cost by pool, per-store freshness, event-table error classifier, DT health |
| `sql/08_teardown.sql` | Dependency-ordered removal |

## Snowflake Objects

| Object | Name | Purpose |
|--------|------|---------|
| Role | `OPENFLOW_ADMIN` | Creates deployment/runtime; opens the canvas |
| Role | `OPENFLOW_SHOPIFY_RUNTIME_EXECUTE_AS_RL` | Identity the connectors run as |
| Role | `SHOPIFY_ANALYST` | Read-only on SHOPIFY_ANALYTICS.CORE |
| Database | `OPENFLOW_DB` | Runtime, network rule, event table |
| Database | `SHOPIFY_RAW` | `META` registry + one schema per store |
| Database | `SHOPIFY_ANALYTICS` | Dynamic Tables and ops view |
| Warehouse | `SHOPIFY_INGEST_WH` | XSMALL; connector CREATE TABLE / MERGE only |
| Warehouse | `SHOPIFY_ANALYTICS_WH` | XSMALL; DT refreshes |
| Network rule | `OPENFLOW_SHOPIFY_RUNTIME_NETWORK_RULE` | All store domains + GCS host |
| EAI | `OPENFLOW_SHOPIFY_RUNTIME_EAI` | Wraps the rule; granted to execute-as role |
| Procedure | `SHOPIFY_RAW.META.ADD_STORE` | Register store, create schema, grant |
| Procedure | `SHOPIFY_RAW.META.REBUILD_ANALYTICS_DTS` | Regenerate UNION ALL DTs |

## Extension Playbook: Add a new Shopify object type (e.g. products)

1. **Shopify scope** — add `read_products` to each store's dev app, **Release** a new
   version, **Install** again on the store. Scopes do not apply until reinstall.
2. **Override JSON** — append an entry to `config/shopify_object_override.json` with
   `apiType: "products"`, `tableName: "PRODUCTS"`, `gidTypeName: "Product"`, a
   `graphqlFields` list, and `promotedColumns` for anything the DTs will filter or sum.
   Validate: `python3 -c "import json,sys; d=json.load(open('config/shopify_object_override.json')); sys.exit(0 if isinstance(d,list) else 1)"`.
3. **Canvas, per store** — Parameters → add `products` to **Objects to Sync**, paste the
   new override → re-enable controller services → Start. The connector runs a bulk load
   for the new object only.
4. **Generator** — in `06_analytics_layer.sql`, add a `v_products` string in the FOR loop
   mirroring `v_orders`, and a fifth `EXECUTE IMMEDIATE ... PRODUCTS_ALL`. Re-create the
   procedure and `CALL REBUILD_ANALYTICS_DTS('24 hours')`.
5. **Verify** — `DESCRIBE TABLE SHOPIFY_RAW.<STORE>.PRODUCTS` shows the promoted columns;
   `SELECT COUNT(*) FROM SHOPIFY_ANALYTICS.CORE.PRODUCTS_ALL GROUP BY store_key`.

## Gotchas

- **Shopify connector is gen 1.** No `CREATE OPENFLOW CONNECTOR` definition exists. Only
  Postgres/MySQL CDC are gen 2 today. Re-check the gen 2 catalog at each expiry review.
- **Never `CREATE OR REPLACE` the network rule or EAI.** It silently detaches from every
  runtime. Use `ALTER ... SET VALUE_LIST` with the full list (`NETWORK_RULE_VALUE_LIST` view).
- **ACCOUNTADMIN default role cannot open the canvas.** Hard login error. `01` fixes it.
- **Management Services pool bills with zero runtimes.** Only `DROP OPENFLOW DEPLOYMENT` stops it.
- **No per-runtime cost attribution** on Snowflake deployments; `OPENFLOW_USAGE_HISTORY` is BYOC-only.
- **`METERING_DAILY_HISTORY` has no `NAME` column.** Use `METERING_HISTORY` to filter by pool/warehouse.
- **Raw payload column name is undocumented.** DTs rely on promoted columns only; `DESCRIBE TABLE` after first load.
- **Event-table runtime-name attribute key is undocumented.** `07` query C assumes
  `openflow.runtime.name`; inspect `resource_attributes` once and adjust.
- **Apostrophes inside generated DDL COMMENTs break the procedure.** `''All stores''` inside
  a `$$` body yields one quote in the emitted SQL. Comments in `REBUILD_ANALYTICS_DTS` avoid them.
- **60-day order window** is Shopify's `read_orders` rule; `read_all_orders` needs approval,
  then a state reset for `orders`.
- **No schema evolution.** Reset object state + drop table, per store.
- **Incremental child cap 250** per parent; bulk load is exempt.
- **One bulk op per shop at a time**; another integration on the same shop blocks the connector.
- **Sizing is unmeasured.** MEDIUM 1–2 nodes is a starting point from CDC heuristics; no
  Shopify guidance exists. Measure after each batch of five stores.
