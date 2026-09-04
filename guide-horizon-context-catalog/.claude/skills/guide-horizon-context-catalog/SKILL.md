---
name: guide-horizon-context-catalog
description: "Guide: Horizon Context + Cortex Sense catalog pivot. Triggers: horizon context, select star, cortex sense, catalog, metadata connectors, dual security boundary, semantic view scoping, context layer"
---

# Guide: Horizon Context + Cortex Sense

Pair-programmed by SE Community + Cortex Code

## Purpose

SE field guide explaining Snowflake's catalog pivot: the announced agreement to acquire Select Star technology → Horizon Context → Cortex Sense. Covers the full three-layer stack, the shift from explicit to dynamic context, and the security boundary questions customers will ask.

## Architecture

```text
Horizon Catalog      ← native Snowflake object inventory
      ↓
Horizon Context      ← extends to external systems (Select Star tech)
      ↓
Cortex Sense         ← announced context activation for CoCo queries
```

## Key Files

| File | Role |
|---|---|
| `README.md` | Full guide — the main deliverable |
| `ELI5.md` | Plain-language summary; must stay factually aligned with the README |
| `docs/01-WHAT-CAN-I-DO-NOW.md` | Action checklist; separates GA work from preview requests |
| `AGENTS.md` | Project-specific conventions and claim rules |
| `.claude/skills/guide-horizon-context-catalog/SKILL.md` | This maintenance workflow |

## Extension Playbook

### How to add a new connector when Wave 2 ships

1. Check the Snowflake docs page for Horizon Catalog connectors for the updated list
2. Update the Availability table in `README.md`
3. Update the availability boundary and preparation checklist in `docs/01-WHAT-CAN-I-DO-NOW.md`
4. If any private preview item moved to GA, remove the preview qualifier
5. Re-run `applyrules` and push

## Snowflake Objects

None. Documentation-only guide.

## Gotchas

- Cortex Sense was announced for private preview in mid-July 2026 with one designated role; current account access requires confirmation. Per-role contexts were described as future work. Do not claim transparent Sense injection into every agent or AI request.
- Benchmark numbers (24% → 86%, $1.76 → $0.59) are Snowflake's *internal* test results. Always include that qualifier.
- Snowflake announced a definitive agreement to acquire Select Star's team and platform technology; the cited announcement does not establish closing. The standalone product roadmap is also unconfirmed.
- The question "is Sense retrieval for a configured agent further bounded by its declared tools" is unanswered publicly. Do not assert either way. Separately, Agent execution uses the querying user's default role, configured tools require privileges, and Restricted Session Scope can impose an agent-session privilege ceiling.
