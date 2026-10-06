---
name: guide-shopify-multistore-snowflake
description: >
  Land daily order, line-item, shipment, and fulfillment data from dozens of Shopify
  stores into Snowflake, on either of two documented paths: the Preview Openflow Shopify
  connector, or a GA native Bulk API pipeline operated through CoCo Desktop. Both publish
  one shared analytics contract. Triggers: shopify snowflake, openflow shopify, multiple
  shopify stores, replace fivetran shopify, shopify bulk api, shopify ingestion failed,
  add shopify store, shopify backfill, shopify api version, reconcile shopify, rotate
  shopify secret, daily shop activity, openflow cost floor.
---

# Guide: Dozens of Shopify Stores into Snowflake

Pair-programmed by SE Community + Cortex Code

## Purpose

Reference guide for a Snowflake admin replacing a third-party Shopify ELT contract. Covers
the honest path decision, the path-independent Shopify and registry work, one analytics
contract both paths satisfy, and two full implementations.

## Structure

| File | Role |
| --- | --- |
| `README.md` | The decision, Shopify prep, shared registry, **the one analytics contract**, monitoring intent, cutover runbook |
| `path-openflow.md` | Openflow deployment/runtime DDL, canvas runbook, object override, scaling, state-reset runbook |
| `path-native-coco.md` | EAI + secrets, generated bindings, pull procedure, qualification, CoCo playbooks, automations |
| `AGENTS.md` | Conventions and the contract invariants that must not be "simplified" |
| `ELI5.md` | Plain-language companion |

## Which path

| Choose | When |
| --- | --- |
| Openflow | Extraction logic maintained by Snowflake is worth accepting a **Preview** connector; store count modest and stable; per-store cost attribution not needed; always-on floor acceptable |
| Native + CoCo | Large or growing store count; need zero idle cost or per-store cost attribution; want every component GA; want to prove a store before promoting it |

## Key Files

| File | Role |
| --- | --- |
| `sql/shared/01_store_registry.sql` | `SHOPIFY_CONTROL`, `STORE_REGISTRY`, `ADD_STORE()`, reconciliation baseline |
| `sql/shared/02_analytics_contract.sql` | Contract as data + `V_CONTRACT_CONFORMANCE` |
| `sql/shared/03_monitoring.sql` | Freshness, registry hygiene, conformance, reconciliation, grain test |
| `sql/openflow/01-04` | Core grants, deployment, execute-as role + EAI, runtime |
| `sql/openflow/05_store_schemas.sql` | Per-store landing schemas from the shared registry |
| `sql/openflow/06_analytics_layer.sql` | `REBUILD_ANALYTICS_DTS()`, contract, published views |
| `sql/openflow/07_monitoring.sql` | Pool credits, event-table classifier, shop/schema mismatch |
| `sql/openflow/08_teardown.sql` | Dependency-ordered removal |
| `config/shopify_object_override.json` | Connector override: orders → 3 tables + fulfillment orders |
| `sql/native/01-04` | Landing, network rule + secret pattern, pull procedure, suspended task |
| `sql/native/05_analytics_layer.sql` | Typed Dynamic Tables, contract, published views |
| `sql/native/06_monitoring.sql` | Health, task history, per-store credits, failure classifier |
| `sql/native/07_teardown.sql` | Dependency-ordered removal |
| `tools/generate_store_bindings.py` | Validates stores; generates EAI, grants, registry MERGE, bindings |
| `coco/BUILD_PLAYBOOK.md` | **The** gate sequence and pilot command |
| `coco/TROUBLESHOOTING_PLAYBOOK.md` | Boundary-first incident workflow |
| `coco/MAINTENANCE_PLAYBOOK.md` | Store, schema, secret, API, path-switch lifecycle |

## The contract

`SHOPIFY_CONTROL.META.V_DAILY_SHOP_ACTIVITY`, grain
`(STORE_KEY, ACTIVITY_DATE, CURRENCY_CODE)`, 14 columns: `STORE_KEY`, `SHOP_URL`,
`ACTIVITY_DATE`, `CURRENCY_CODE`, `ORDERS_PLACED`, `ORDERS_CANCELLED`, `UNITS_SOLD`,
`GROSS_SALES`, `DISCOUNTS`, `REFUNDS`, `NET_SALES`, `SHIPMENTS_CREATED`,
`SHIPMENTS_SUCCESS`, `SHIPMENTS_DELIVERED`. Defined in README.md; enforced by
`V_CONTRACT_CONFORMANCE`. Never edit one path's column list alone.

## Extension Playbook: add a Shopify object type

1. **Shopify** — add the read scope to each store's dev app, **Release** a new version,
   **Install** again. Scopes do not apply until reinstall.
2. **Openflow path** — append an entry to `config/shopify_object_override.json` with
   `apiType`, `tableName`, `gidTypeName`, `graphqlFields`, and `promotedColumns`; validate
   it is a JSON array; add the object to **Objects to Sync** per store; add a matching
   string and `EXECUTE IMMEDIATE` to `REBUILD_ANALYTICS_DTS()`; rebuild.
3. **Native path** — extend the GraphQL selection in `sql/native/03_pull_procedure.sql`
   (respect 5 connections / 2 nesting levels), add a typed Dynamic Table, qualify one
   store, then widen.
4. **Both** — re-run the contract conformance check. If the new object changes
   `DAILY_SHOP_ACTIVITY`, update README.md and `CONTRACT_COLUMNS` first, then both paths.

## Gotchas

- **Shopify connector is Preview**; Openflow Snowflake Deployments are GA. Load-bearing
  for the decision.
- **API 2026-01+: five concurrent bulk query operations per APP per shop.** Per app, so
  another vendor's integration on the same store does not consume your slots. Earlier
  versions allowed one of each type.
- **Poll with `bulkOperation(id:)`**, not `currentBulkOperation`.
- **Object grouping is off by default** for `bulkOperationRunQuery`; join children by
  `__parentId`, never by row order.
- **Openflow: Management Services pool bills with zero runtimes.** Only
  `DROP OPENFLOW DEPLOYMENT` stops it. Suspending the runtime does not.
- **Openflow: no per-runtime or per-store cost attribution.** `OPENFLOW_USAGE_HISTORY` is
  BYOC-only. `METERING_DAILY_HISTORY` has no `NAME` column; use `METERING_HISTORY`.
- **Openflow: no sizing heuristic for this workload.** CDC packing guidance (MEDIUM 5–8) is
  the only published number and this workload is lighter. Measure.
- **Openflow: `NODE_TYPE` is immutable.** Add a runtime rather than resize.
- **Openflow: ACCOUNTADMIN default role cannot open the canvas.** Hard login error.
- **Openflow: no schema evolution.** State reset plus table drop, per store.
- **Openflow: incremental child cap is 250** line items per parent; the bulk load is exempt.
- **Openflow: raw payload column name is undocumented**; DTs use promoted columns only.
  `DESCRIBE TABLE` after the first load.
- **Openflow: event-table runtime-name attribute key is undocumented**; query B1 assumes
  `openflow.runtime.name` — inspect `resource_attributes` once and adjust.
- **Openflow: apostrophes inside generated DDL comments** break the generator procedure.
- **Native: `Session.sql("PUT")` is unsupported** in stored procedures; use
  `session.file.put_stream`.
- **Native: result URLs expire after seven days.**
- **Native: do not call Shopify from an automation.** Cloud-agent EAI support is
  conflicting in current docs; automations are read-only supervisors.
- **Native: workspace mounts do not support append**; automations overwrite a dated file.
- **Both: 60-day `read_orders` window**; `read_all_orders` needs Shopify approval, then a
  backfill (native) or an object state reset (Openflow).
- **Both: `read_customers` is protected customer data** and is deliberately omitted.
- **Both: no stable egress IP**, so neither path suits a store that allowlists inbound API
  access by IP.
