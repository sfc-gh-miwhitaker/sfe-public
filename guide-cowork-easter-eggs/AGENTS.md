# guide-cowork-easter-eggs — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Do not duplicate them here. -->

This is a documentation-only guide. No SQL objects, no deploy script.

## Architecture

```
guide-cowork-easter-eggs/
  README.md        — Main guide (15 status-aware feature sections)
  WHAT-CAN-I-DO-NOW.md — Outcome-based action menu with runnable prompts
  ELI5.md          — Plain-language companion for non-technical readers
  AGENTS.md        — This file
  .builddemo-state.json — Build state (gitignored)
```

The guide is organized by **surprise value** — features ranked from most-overlooked to best-known, not alphabetically. The `## Start Here` section routes readers to the right entry point for their context (demo prep, customer rollout, enterprise config).

## Conventions

- Feature sections are numbered 1–15. Additions go at the end (or renumbered if dramatically more impactful than existing entries).
- Preview features are labeled inline with `(Preview)` in current sections. Restricted previews and roadmap items stay in **What's Still Emerging**.
- The **Common Misconceptions** and **What's Still Emerging** tables are the two highest-maintenance sections. Update them first when capabilities change stage.
- Expiry is 2026-12-04. Re-verify every preview label, prerequisite, limitation, and emerging capability at each review.

## Key Commands

```bash
# Pre-commit check
pre-commit run --files guide-cowork-easter-eggs/README.md

# Verify guide renders cleanly (no broken links, badge format)
# Open README.md in a Markdown previewer — no deploy step needed
```

## When Updating This Guide

1. Check Snowflake release notes and CoWork release channels for new CoWork features.
2. Move broadly available capabilities into the main numbered sections with an explicit GA or Preview label.
3. Update the **Misconceptions** table if any misconceptions are now corrected by GA behavior.
4. Update WHAT-CAN-I-DO-NOW.md, ELI5.md, and `.claude/skills/guide-cowork-easter-eggs/SKILL.md` so their capabilities and limitations match the README.
5. Bump the `Expires` badge and metadata line using a three-month review cadence while Preview features remain prominent.
6. Run pre-commit before committing.
