---
name: guide-cortex-sense
description: "Deep-dive SE guide on Cortex Sense runtime context layer, Horizon Context stack, Summit 2026 announcements, self-correcting eval loop, benchmark positioning. Use when: Cortex Sense, Horizon Context, context layer, semantic autopilot, agent accuracy, Summit 2026 AI stack."
---

# Cortex Sense Guide

## Purpose

Explain the full Horizon Catalog -> Horizon Context -> Cortex Sense stack to SE peers. Covers what's new at Summit 2026, how the self-correcting evaluation loop works, benchmark numbers and their limitations, and brief competitive positioning against Databricks Genie Ontology.

## Architecture

Documentation-only guide. Single README.md with inline Mermaid diagrams.

```
guide-cortex-sense/
  README.md       -- Full deep-dive (the deliverable)
  AGENTS.md       -- Project instructions
  .claude/skills/guide-cortex-sense/SKILL.md  -- This file
```

## Key Files

| File | Role |
|---|---|
| `README.md` | Main guide — three-layer stack, Cortex Sense deep dive, benchmarks, positioning |
| `AGENTS.md` | Project conventions and refresh triggers |

## Snowflake Objects

None — this is a documentation-only guide. No deploy scripts.

## Extension Playbook: Adding a New Section

1. Identify the new feature or announcement to cover
2. Verify facts against official Snowflake blog or docs (never analyst-only sources)
3. Add maturity label (GA / Private preview / Public preview / Planned)
4. Update the Maturity Summary table at bottom of README
5. If the feature belongs to an existing layer (Catalog/Context/Sense), add it under that section
6. If it's a new layer or cross-cutting concern, add a new H2 section before "Competitive Note"
7. Update the created date if making substantial changes

## Gotchas

- Cortex Sense is private preview — facts may change before GA. Always include the forward-looking disclaimer.
- The ~86% benchmark is Snowflake's own internal test, not an independent third-party audit. Position honestly.
- "Included with Cortex AI" does not mean zero cost — there's a one-time indexing cost plus ongoing per-query context delivery cost. It means no separate SKU.
- Cortex Sense serves context to CoWork/CoCo/Cortex Agents only. Claude Desktop or Cursor users benefit indirectly via semantic view MCP, not via Cortex Sense directly.
- The self-correcting loop requires human input for ambiguous conflicts — it's not fully autonomous.
