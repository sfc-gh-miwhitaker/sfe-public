# guide-shopify-bulk-api-coco — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and the root sfe-public AGENTS.md.
     Do not duplicate them here. -->

Pair-programmed by SE Community + Cortex Code

## Architecture

CoCo Desktop is the lifecycle interface. A deterministic Snowflake pipeline performs
the data movement: Python stored procedure → Shopify Bulk API → internal stage → COPY →
Dynamic Tables. A read-only CoCo automation supervises the pipeline.

## Conventions

- Production data movement never depends on an LLM response.
- CoCo deployment playbooks enforce documentation, security, compilation,
  connectivity, extraction, landing, loading, contract, reconciliation, scheduling,
  and rollback gates.
- Shopify credentials are Snowflake SECRET objects. Never place values in source files.
- All generated SQL uses fully qualified object names and explicit column lists.
- Tasks remain suspended until the pilot-store qualification passes.

## Key Commands

```sql
CALL SHOPIFY_NATIVE.CONTROL.QUALIFY_STORE('STORE_ALPHA', NULL);
CALL SHOPIFY_NATIVE.CONTROL.PULL_STORE('STORE_ALPHA', 'ORDERS', NULL);
SELECT STORE_KEY, OBJECT_NAME, LAST_RUN_STATUS, LAST_COMPLETED_AT
FROM SHOPIFY_NATIVE.CONTROL.V_PIPELINE_HEALTH ORDER BY STORE_KEY;
```

```bash
cortex automation doctor shopify_pipeline_daily
```
