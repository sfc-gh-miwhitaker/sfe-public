---
name: guide-horizon-context-catalog
description: "Guide: Horizon Context + Cortex Sense context stack. Triggers: horizon context, cortex sense, horizon catalog, metadata connectors, agent security boundary, semantic view scoping, context layer, apache ossie, certification status tag"
---

# Guide: Horizon Context + Cortex Sense

Pair-programmed by SE Community + Cortex Code

## Purpose

SE field guide explaining Snowflake's context stack: Horizon Catalog → Horizon Context → Cortex Sense. Covers the three-layer separation, the shift from explicit to dynamic context, the verified availability status of each piece, and the agent security-boundary questions customers will ask. Carries no competitive positioning or objection-handling content by design.

## Architecture

```text
Horizon Catalog      ← native Snowflake object inventory
      ↓
Horizon Context      ← extends to external systems (connectors, OpenLineage)
      ↓
Cortex Sense         ← announced context activation for CoCo queries
```

## Key Files

| File | Role |
| --- | --- |
| `README.md` | Full guide — the main deliverable |
| `ELI5.md` | Plain-language summary; must stay factually aligned with the README |
| `docs/01-WHAT-CAN-I-DO-NOW.md` | Action checklist; separates GA work from preview requests |
| `AGENTS.md` | Project-specific conventions and claim rules |
| `.claude/skills/guide-horizon-context-catalog/SKILL.md` | This maintenance workflow |

## Extension Playbook

### How to re-verify statuses on expiry

1. Check each row of the README Availability table against `snowflake_product_docs`, looking for a dated release note or a documentation page
2. Where no source exists, write "unconfirmed — verify with your account team". Never infer a maturity level from a blog announcement
3. Update the *changed* markers and the re-verification date in the availability caveat and table intro
4. Re-check the Cortex Sense tool-scope question and update its "Status as of" date, whether or not the answer moved
5. Update `ELI5.md` and `docs/01-WHAT-CAN-I-DO-NOW.md` to match
6. Re-run `applyrules` and push

## Snowflake Objects

None. Documentation-only guide.

## Gotchas

- Cortex Sense has **no GA release note and no product documentation page** (re-verified 2026-09-21). Never label it GA. The announced initial model used one designated role with per-role contexts as future work. Do not claim transparent Sense injection into every agent or AI request.
- Benchmark numbers (24% → 86%, $1.76 → $0.59) are Snowflake's *internal* test results. Always include that qualifier.
- The question "is Sense retrieval for a configured agent further bounded by its declared tools" is still unanswered publicly. Do not assert either way, and re-verify rather than restate it on each revision. Separately, Agent execution uses the querying user's default role, configured tools require privileges, and Restricted Session Scope can impose an agent-session privilege ceiling.
- External lineage (the OpenLineage path) is **GA since 2026-09-03** and Semantic Studio is **public preview since 2026-08-26**. Both were previously recorded at lower maturity; check for similar drift on the remaining rows.
- `SNOWFLAKE.CORE.CERTIFICATION_STATUS` is still supported and **not yet deprecated** — only documented as planned for deprecation. `SNOWFLAKE.TAGS.CERTIFICATION_STATUS` is the public-preview replacement. Do not state that the CORE tag has been removed.
- Use "CoWork" in prose; the `SNOWFLAKE_INTELLIGENCE` database identifier in DDL is unchanged.
