# guide-cowork-easter-eggs — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Do not duplicate them here. -->

This is a documentation-only guide. No SQL objects, no deploy script.

## Architecture

```
guide-cowork-easter-eggs/
  README.md        — Main guide (15 feature sections)
  ELI5.md          — Plain-language companion for non-technical readers
  AGENTS.md        — This file
  .builddemo-state.json — Build state (gitignored)
```

The guide is organized by **surprise value** — features ranked from most-overlooked to best-known, not alphabetically. The `## Start Here` section routes readers to the right entry point for their context (demo prep, customer rollout, enterprise config).

## Conventions

- Feature sections are numbered 1–15. Additions go at the end (or renumbered if dramatically more impactful than existing entries).
- Preview features are always labeled inline with `(PrPr)` or `(Preview)`.
- The **Common Misconceptions** table and **What's Coming** table are the two highest-maintenance sections — update them first when CoWork ships new capabilities.
- Expiry is 2027-02-01. When updating, re-verify every item in the **What's Coming** table (some will have gone GA) and every misconception claim.

## Key Commands

```bash
# Pre-commit check
pre-commit run --files guide-cowork-easter-eggs/README.md

# Verify guide renders cleanly (no broken links, badge format)
# Open README.md in a Markdown previewer — no deploy step needed
```

## When Updating This Guide

1. Check Snowflake release notes and CoWork release channels for new CoWork features.
2. Move any "What's Coming" rows to GA status and update their descriptions in the main sections.
3. Update the **Misconceptions** table if any misconceptions are now corrected by GA behavior.
4. Bump the `Expires` badge and the metadata line in README.md header.
5. Run pre-commit before committing.
