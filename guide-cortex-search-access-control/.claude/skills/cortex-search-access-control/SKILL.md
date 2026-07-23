---
name: cortex-search-access-control
description: "Guide for enforcing access control on Cortex Search Services. Covers filter-based UBAC (@contains pattern), separate services per boundary, stored procedure hardening, and honest roadmap for caller's rights. Use when: Cortex Search RBAC, search access control, owner's rights workaround, per-user search, per-tenant search, dynamic search filtering, CRM ID access gate."
---

# Cortex Search Access Control — Project Skill

## Purpose

This guide covers how to enforce access control on Cortex Search Services today. Cortex Search runs with owner's rights — any caller with USAGE on a service sees all indexed content. The guide provides two patterns to work around this, plus an honest roadmap section.

## Architecture

Documentation-only — no SQL objects, no deploy scripts.

```
README.md                  → decision tree, pattern comparison, roadmap
filter-attribute-ubac.md   → Pattern 1: ATTRIBUTES + @contains filter
separate-services.md       → Pattern 2: one service per data boundary
ELI5.md                    → plain-language companion
AGENTS.md                  → project-specific AI instructions
```

Pattern 1 (filter UBAC) is recommended for dynamic / per-identity access (any external identifier: CRM account IDs, tenant IDs, user emails, etc.).
Pattern 2 (separate services) is recommended for static groups where zero leakage is required.

## Key Files

| File | Role |
|---|---|
| `README.md` | Start here — decision tree + pattern comparison table |
| `filter-attribute-ubac.md` | Full walkthrough of the `@contains` ARRAY filter pattern |
| `separate-services.md` | Full walkthrough of the per-boundary service pattern |
| `ELI5.md` | Plain-language companion for non-technical stakeholders |
| `AGENTS.md` | Layer 3 project instructions for AI assistants |

## Snowflake Objects

None. This is a documentation guide with no deployed infrastructure.

## Extension Playbook: Adding a New Access Control Pattern Page

When Snowflake releases a new access control capability (e.g., native caller's rights, row-level policy integration), add it as a new pattern page:

1. Create `<pattern-name>.md` at the project root following the structure of `filter-attribute-ubac.md`:
   - One-line summary of the pattern
   - When to use it (and when not to)
   - Step-by-step implementation with verified SQL/code examples
   - Tradeoffs and gotchas table
   - "When to switch to another pattern" section
   - Back-link to `README.md`

2. Add the new pattern to the Mermaid decision flowchart in `README.md`.

3. Add a row to the Pattern Comparison table in `README.md`.

4. Add rows to the Quick Picks by Scenario table for use cases the new pattern covers.

5. Update the "What's Coming" section in `README.md` — if the new pattern replaces an item there, remove or amend that entry.

6. Update this SKILL.md: add the new file to the Architecture section and Key Files table.

7. Verify: does the new pattern supersede or modify the stored procedure hardening advice in `filter-attribute-ubac.md`? If so, update that file.

## Gotchas

- **ATTRIBUTES column must appear in SELECT.** Declaring a column in `ATTRIBUTES` without including it in the source query's `SELECT` will fail or silently make it unfilterable. Both must be present.
- **`@contains` requires an ARRAY column, not VARCHAR.** Storing a comma-separated string and trying to filter with `@contains` does not work. The column type must be ARRAY.
- **Filter attribute names are case-sensitive in the JSON.** The name in `{ "@contains": { "authorized_ids": ... } }` must match the column name exactly as it appears in the source query. Default Snowflake column names are UPPER_CASE.
- **SEARCH_PREVIEW is not for production.** `SNOWFLAKE.CORTEX.SEARCH_PREVIEW` has higher latency than the REST/Python APIs and is documented for testing and validation only. Production traffic must use the REST or Python API.
- **Owner's rights bypasses row-level masking.** Masking policies on the source table do not restrict Cortex Search results. The ARRAY filter is the only access gate.
- **No filter = full index exposed.** Pattern 1 relies on the calling application injecting the filter. Use the stored procedure wrapper pattern to make this bypass-proof.
- **Caller's rights is not GA.** Do not design for it as a near-term feature. Treat it as "no public roadmap, no date." When asked by customers, say "Snowflake is actively working on native row-level policy support for Cortex Search — ask your account team for the latest status." Do not quote internal Slack discussions or specific timing.
