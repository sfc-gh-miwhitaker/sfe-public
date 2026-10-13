---
name: guide-horizon-context-catalog
description: "Guide: Horizon Context + Cortex Sense context stack. Triggers: horizon context, cortex sense, horizon catalog, metadata connectors, agent security boundary, semantic view scoping, context layer, apache ossie, certification status tag"
---

# Guide: Horizon Context + Cortex Sense

Pair-programmed by SE Community + Cortex Code

## Purpose

Public customer guide explaining Snowflake's context stack: Horizon Catalog → Horizon Context → Cortex Sense. Helps data engineers, stewards, and platform owners choose capabilities, connect sources, and plan access controls. Write directly to the reader; exclude presenter coaching, research narratives, competitive positioning, and objection handling. State limitations and next steps without recounting the verification process.

## Architecture

```text
Horizon Catalog      ← inventory of native and external assets
Horizon Context      ← collect, enrich, activate; documented preview capabilities
Cortex Sense         ← separately qualified runtime context for CoCo queries
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
3. Date changed claims and link their sources. Preserve the full-guide verification and expiry dates for narrow updates; renew only after substantive full-guide verification
4. Re-check the Cortex Sense tool-scope question and update its "Status as of" date, whether or not the answer moved
5. Update `ELI5.md` and `docs/01-WHAT-CAN-I-DO-NOW.md` to match
6. Keep setup instructions, connector lists, detailed grants, and limits in their official documentation. Update this guide's decision points and pointers instead of duplicating those references
7. Check links, consistency, and public-content safety. Run `applyrules` before publication; commit or push only when explicitly requested

## Snowflake Objects

None. Documentation-only guide.

## Gotchas

- Qualify Cortex Sense independently from Horizon Context. Verify availability, supported clients, and retrieval access against current sources; a client release-note mention alone does not establish those guarantees. Keep search history in private memory, not reader-facing pages. Do not claim transparent injection into every agent or AI request.
- Benchmark numbers (24% → 86%, $1.76 → $0.59) are Snowflake's *internal* test results. Always include that qualifier.
- Re-check whether Sense retrieval for a configured agent is bounded by its declared tools. The documented Horizon Context metadata-access model does not settle that runtime question. Review metadata grants independently from data grants, and owner-rights execution separately from the caller's direct privileges.
- `tool_not_accessible: reject` checks only the documented tool set, not every tool or underlying dependency. Link to the current inaccessible-tool handling documentation rather than expanding the guarantee.
- Use the official release notes and feature pages as the availability authority. Do not confuse the GA OpenLineage path, preview metadata connectors, GA Semantic Studio, or separately qualified Cortex Sense. Read feature-specific cloud, region, and source restrictions even when a page says open preview.
- `SNOWFLAKE.CORE.CERTIFICATION_STATUS` is still supported and **not yet deprecated** — only documented as planned for deprecation. `SNOWFLAKE.TAGS.CERTIFICATION_STATUS` is the public-preview replacement. Do not state that the CORE tag has been removed.
- Use "CoWork" in prose; the `SNOWFLAKE_INTELLIGENCE` database identifier in DDL is unchanged.
