# guide-openflow-shopify-multistore — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and the root sfe-public AGENTS.md.
     Do not duplicate them here. -->

Pair-programmed by SE Community + Cortex Code

## Architecture

```
N Shopify stores (one dev app each)
  → one Openflow Snowflake Deployment (gen 2, SQL-created)
  → one MEDIUM runtime, N Shopify connector process groups (gen 1, canvas-installed)
  → SHOPIFY_RAW.<STORE_KEY>.ORDERS / ORDER_LINE_ITEMS / ORDER_FULFILLMENTS / FULFILLMENT_ORDERS
  → SHOPIFY_ANALYTICS Dynamic Tables (UNION ALL across store schemas, SHOP_URL as tenant key)
```

## Conventions

- Infrastructure objects live in `OPENFLOW_DB.OPENFLOW_SCHEMA`; landed data in
  `SHOPIFY_RAW`; analytics in `SHOPIFY_ANALYTICS`. Never mix the three.
- One schema per store, named by `STORE_KEY` (uppercase, `[A-Z0-9_]`), driven by
  `SHOPIFY_RAW.META.STORE_REGISTRY`. The per-store schema and the UNION ALL Dynamic
  Tables are **generated** from the registry, never hand-edited.
- Network rules and EAIs use `CREATE ... IF NOT EXISTS` + `ALTER ... SET`. Never
  `CREATE OR REPLACE` — it silently detaches the object from every runtime that uses it.
- Openflow DDL (`CREATE OPENFLOW DEPLOYMENT/RUNTIME`) cannot be compile-checked in an
  account without Openflow privileges. Those blocks are marked `-- syntax from docs,
  not executed` and must be re-verified against docs.snowflake.com at every expiry review.
- The Shopify connector is **gen 1** (canvas). Do not write `CREATE OPENFLOW CONNECTOR`
  for it — no definition ID exists. Re-check the gen 2 catalog at each expiry review.
- No Shopify Client ID / Client Secret ever appears in a committed file. Placeholders only.

## Key Commands

```sql
-- Wait for infrastructure
SELECT SYSTEM$WAIT_FOR_OPENFLOW_DEPLOYMENT_STATUS('SHOPIFY_DEPLOYMENT', 'ACTIVE', 900);
SELECT SYSTEM$WAIT_FOR_OPENFLOW_RUNTIME_STATUS('OPENFLOW_DB.OPENFLOW_SCHEMA.SHOPIFY_RUNTIME', 'ACTIVE', 600);

-- Add a store (after Shopify dev app exists)
CALL SHOPIFY_RAW.META.ADD_STORE('STORE_KEY', 'store.myshopify.com', 'owner@example.com');
CALL SHOPIFY_RAW.META.REBUILD_ANALYTICS_DTS();

-- Per-store freshness
SELECT * FROM SHOPIFY_ANALYTICS.STORE_FRESHNESS ORDER BY hours_since_last_update DESC;
```
