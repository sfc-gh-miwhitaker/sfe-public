---
name: team-standards
description: "Use when reviewing SQL for quality, checking naming conventions, or verifying code before commit. Handles SQL sargability, window function patterns, credential scanning, and naming convention enforcement."
---

# Team Standards Review

## When to Use

Invoke this skill when writing or reviewing SQL, checking code before commit, or when you notice the AI drifting from conventions mid-session.

## Workflow

1. **Check SQL quality** -- scan for SELECT *, non-sargable WHERE predicates, window functions without QUALIFY, and mismatched join types. See `references/standards.md` for the full rules.
2. **Check naming** -- verify objects follow the team's naming patterns ({TEAM_PREFIX}_, RAW_, STG_ prefixes, COMMENT on all objects).
3. **Check security** -- confirm no credentials, API keys, account IDs, or customer names appear in code or output.
4. **Report** -- list any violations found with the specific line and fix.

## Compaction Recovery

If the AI forgets conventions mid-session, context compaction likely happened. Recovery:
1. Re-read `~/.claude/CLAUDE.md` (the always-on standards)
2. Re-invoke this skill
3. Re-read the project's `AGENTS.md`

## Evolving This Skill

After every session where the AI made a mistake your standards should have caught, ask: "What did we just learn that should be added to our standards?" Update `~/.claude/CLAUDE.md` for always-on rules, or `references/standards.md` for detailed reference.
