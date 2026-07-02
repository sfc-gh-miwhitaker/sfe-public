# Cortex Sense Guide — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

This is a documentation-only guide (no deploy scripts, no Snowflake objects). Content structure:

```
guide-cortex-sense/
  README.md           -- Main deep-dive guide (the deliverable)
  AGENTS.md           -- This file
  .claude/skills/guide-cortex-sense/SKILL.md
```

The README covers the full Horizon Catalog -> Horizon Context -> Cortex Sense stack with inline Mermaid diagrams. All facts are sourced from official Snowflake blogs (Jun 2 and Jun 30, 2026) and analyst coverage.

## Conventions

- All Mermaid diagrams are inline in README.md (no separate diagram files)
- Maturity labels (GA / Private preview / Public preview / Planned) on every feature
- Forward-looking disclaimer at the top since Cortex Sense is private preview
- No customer names or account identifiers
- Benchmark numbers sourced from official Snowflake blog only

## Key Commands

- **Update:** Edit README.md directly. All content is in one file.
- **Verify facts:** Cross-reference against the two official Snowflake blogs linked in References section.
- **Check maturity:** Cortex Sense status may change — check docs.snowflake.com release notes.

## Content Refresh Triggers

Update this guide when:
- Cortex Sense moves from private preview to public preview or GA
- Per-role context scoping ships
- New Horizon Context connectors are announced
- Benchmark numbers are updated with external validation
- Advanced Semantics or Semantic Studio reach GA
