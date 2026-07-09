---
name: guide-horizon-context-catalog
description: "Guide: Horizon Context + Cortex Sense catalog pivot. Triggers: horizon context, select star, cortex sense, catalog, metadata connectors, dual security boundary, semantic view scoping, context layer"
---

# Guide: Horizon Context + Cortex Sense

## Purpose
SE field guide explaining Snowflake's catalog pivot: Select Star acquisition → Horizon Context → Cortex Sense. Covers the full three-layer stack, the shift from explicit to dynamic context, and the security boundary questions customers will ask.

## Architecture
```
Horizon Catalog      ← native Snowflake object inventory
      ↓
Horizon Context      ← extends to external systems (Select Star tech)
      ↓
Cortex Sense         ← activates context at runtime for AI queries
```

## Key Files

| File | Role |
|---|---|
| `README.md` | Full guide — the main deliverable |
| `AGENTS.md` | Project-specific conventions and claim rules |

## Extension Playbook

### How to add a new connector when Wave 2 ships
1. Check the Snowflake docs page for Horizon Catalog connectors for the updated list
2. Update the Availability table in `README.md`
3. If any private preview item moved to GA, remove the preview qualifier
4. Re-run `applyrules` and push

## Snowflake Objects

None. Documentation-only guide.

## Gotchas

- Cortex Sense private preview (mid-July 2026): single-role access only. Per-role context scoping is roadmap. Don't claim it's available.
- Benchmark numbers (24% → 86%, $1.76 → $0.59) are Snowflake's *internal* test results. Always include that qualifier.
- Select Star standalone product roadmap is unconfirmed. Say "technology being integrated" not "product winding down."
- The question "does Sense respect agent tool boundaries vs only RBAC" is unanswered publicly. Do not assert either way.
