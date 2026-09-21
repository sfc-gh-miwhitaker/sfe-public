# guide-shopify-multistore-snowflake — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and the root sfe-public AGENTS.md.
     Do not duplicate them here. -->

Pair-programmed by SE Community + Cortex Code

## Architecture

One guide, two implementation paths, one analytics contract.

```text
                 SHOPIFY_CONTROL.META  (shared, path-independent)
                   STORE_REGISTRY · RECONCILIATION_BASELINE
                   CONTRACT_COLUMNS · V_CONTRACT_CONFORMANCE
                   V_DAILY_SHOP_ACTIVITY · V_STORE_FRESHNESS   ← published surfaces
                        ▲                              ▲
        ┌───────────────┘                              └───────────────┐
  Openflow path                                              Native path
  N dev apps → OPENFLOW DEPLOYMENT (SQL)                 N dev apps → Python procedure
    → RUNTIME + N canvas-installed connectors              → Bulk API → stage → COPY
    → SHOPIFY_RAW.<STORE_KEY>.{4 tables}                   → SHOPIFY_NATIVE.LANDING.SHOPIFY_RAW
    → generated UNION ALL Dynamic Tables                   → static CREATE OR ALTER Dynamic Tables
    → SHOPIFY_ANALYTICS.CORE.DAILY_SHOP_ACTIVITY           → SHOPIFY_NATIVE.ANALYTICS.DAILY_SHOP_ACTIVITY
```

Exactly one path owns the two published views at a time. Deploying the other path's
analytics file replaces them.

## Conventions

- **The contract is defined once.** README.md "The one analytics contract" is the
  definition; `SHOPIFY_CONTROL.META.CONTRACT_COLUMNS` encodes it as data. Both
  `sql/*/0*_analytics_layer.sql` files must conform. Never change one implementation's
  column list without changing the README, the contract table, and the other path.
- **The registry is shared.** `SHOPIFY_CONTROL.META.STORE_REGISTRY` is the only store
  registry. Do not add a second one to either path. `CREDENTIAL_OBJECT_FQN` is NULL on
  the Openflow path.
- **Path-independent content lives in README.md only.** Shopify app and scope work, the
  API version decision, the registry, the contract, the monitoring intent, and the cutover
  runbook are stated there once. `path-*.md` must reference, never restate.
- **The CoCo gate table and pilot command live in `coco/BUILD_PLAYBOOK.md` only.** That is
  what CoCo reads. `path-native-coco.md` links to it.
- **Pin the Shopify API version explicitly, 2026-01 or later**, on both paths. Five
  concurrent bulk query operations **per app** per shop; poll with `bulkOperation(id:)`;
  object grouping is off by default, so join children by `__parentId`.
- **Openflow DDL cannot be compile-checked** without Openflow privileges. Those blocks are
  marked `-- syntax from docs, not executed` and must be re-verified at every expiry
  review.
- **The Shopify connector is gen 1** (canvas). Do not write `CREATE OPENFLOW CONNECTOR`
  for it — no definition ID exists. Re-check the gen 2 catalog at each expiry review.
- **Never `CREATE OR REPLACE` a network rule or EAI.** It silently detaches the object from
  every runtime that uses it. Use `ALTER ... SET VALUE_LIST` with the full list.
- **In `GROUP BY`, use the expression, not an output alias**, when a joined table may carry
  a same-named column. Verified: Snowflake resolves the alias to the joined column and
  either errors or regroups silently.
- No Shopify Client ID or Client Secret in any committed file. Placeholders only.

## Contract invariants — do not "simplify" these

| Invariant | Why |
| --- | --- |
| `FULL OUTER JOIN` between the order day frame and the shipment day frame | A `LEFT JOIN` from orders drops every day with shipments but no orders processed. That is data loss, not simplification |
| `CURRENCY_CODE` in every day-frame join predicate | Omitting it fans one shipment row across every currency row of a multi-currency store |
| Shipments `LEFT JOIN` orders for currency | An inner join drops shipments whose parent order is outside the 60-day window |
| `NET_SALES = GROSS_SALES - REFUNDS` | Shopify's `TOTAL_PRICE` is already net of discounts; subtracting discounts again double-counts |
| Test orders excluded, including their shipments | Otherwise test traffic inflates every measure |
| Measures `COALESCE`d to 0 | A row exists only when there was activity, so zero is a fact, not a NULL |

## Key Commands

```sql
-- Shared: register a store (never activates it)
CALL SHOPIFY_CONTROL.META.ADD_STORE('STORE_KEY', 'store.myshopify.com', 'owner@example.com');

-- Shared: is the deployed implementation still on contract?
SELECT COUNT_IF(STATUS <> 'OK') AS CONTRACT_VIOLATIONS
FROM SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE;

-- Shared: freshness
SELECT STORE_KEY, HOURS_SINCE_LAST_UPDATE, ORDERS_LOADED
FROM SHOPIFY_CONTROL.META.V_STORE_FRESHNESS
ORDER BY HOURS_SINCE_LAST_UPDATE DESC NULLS FIRST;

-- Openflow path: rebuild the generated UNION ALL layer after a store change
CALL SHOPIFY_RAW.PUBLIC.CREATE_STORE_SCHEMA('STORE_KEY');
CALL SHOPIFY_ANALYTICS.CORE.REBUILD_ANALYTICS_DTS('24 hours');

-- Native path: qualify one store with the schedule still suspended
CALL SHOPIFY_NATIVE.CONTROL.QUALIFY_STORE('STORE_ALPHA', NULL);
SELECT STORE_KEY, OBJECT_NAME, LAST_RUN_STATUS, LAST_COMPLETED_AT
FROM SHOPIFY_NATIVE.CONTROL.V_PIPELINE_HEALTH ORDER BY STORE_KEY;
```

```bash
python3 tools/generate_store_bindings.py config/stores.json
cortex automation doctor shopify_pipeline_daily
```
