# guide-cowork-easter-eggs — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Do not duplicate them here. -->

This is a documentation-only guide. No SQL objects, no deploy script.

## Architecture

```text
guide-cowork-easter-eggs/
  README.md        — Main guide (15 status-aware feature sections)
  WHAT-CAN-I-DO-NOW.md — Outcome-based action menu with runnable prompts
  ELI5.md          — Plain-language companion for non-technical readers
  AGENTS.md        — This file
```

The guide is organized by **surprise value** — features ranked from most-overlooked to best-known, not alphabetically. The `## Start Here` section routes readers to the right entry point for their context (demo prep, customer rollout, enterprise config).

## Conventions

- Feature sections are numbered 1–15. Additions go at the end (or renumbered if dramatically more impactful than existing entries).
- Availability labels and feature claims must cite public documentation or public announcements. Omit claims supported only by internal rollout information.
- Re-check the **Surface Map** and **Common Misconceptions** tables when capabilities change stage.
- Use the README's review and expiry dates; follow the repository's 60-day maximum lifetime.

## Key Commands

```bash
# Pre-commit check
pre-commit run --files guide-cowork-easter-eggs/README.md

# Verify guide renders cleanly (no broken links, badge format)
# Open README.md in a Markdown previewer — no deploy step needed
```

## When Updating This Guide

1. Check public Snowflake documentation and release notes for new CoWork features.
2. Move broadly available capabilities into the main numbered sections with an explicit GA or Preview label.
3. Update the **Misconceptions** table if any misconceptions are now corrected by GA behavior.
4. Update WHAT-CAN-I-DO-NOW.md and ELI5.md so their capabilities and limitations match the README.
5. Update review dates only after substantive verification; keep detailed review evidence outside the public repository.
6. Run pre-commit before committing.
