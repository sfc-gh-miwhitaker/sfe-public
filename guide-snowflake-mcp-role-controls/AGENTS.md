# Snowflake MCP Role Controls - Project Instructions

Pair-programmed by SE Community + Cortex Code

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Static guide with ordered Snowflake SQL templates. No data model, warehouse, or deployed application is included.

## Conventions

- Keep primary-role OAuth controls separate from secondary-role session-policy controls.
- Label Preview features explicitly and re-check their status before extending the guide.
- Use generic uppercase placeholders and never include customer identifiers.

## Key Commands

```bash
pre-commit run --all-files
```
