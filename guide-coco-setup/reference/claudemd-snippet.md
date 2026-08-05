# Example ~/.claude/CLAUDE.md Snippet

> Copy the section below into `~/.claude/CLAUDE.md` to make these standards always-on across all projects and sessions. Replace `{PLACEHOLDER}` values with your team's conventions.

This file is read by Cortex Code (Desktop + CLI), Claude Code, and Cursor — write once, works everywhere.

```markdown
## SQL Standards
- Never use SELECT * in production code -- always project specific columns
- Sargable predicates only: never wrap columns in functions in WHERE clauses
- Use QUALIFY for window function filtering, not subquery wrapping
- Join keys must have matching types -- no implicit casts
- Set STATEMENT_TIMEOUT_IN_SECONDS on warehouses to prevent runaway queries

## Security
- Never commit credentials, API keys, .env files, or account identifiers
- Use Snowflake secrets or environment variables for all credentials
- Use detect-secrets or similar pre-commit hooks to catch leaked secrets

## Naming Conventions
- Database: {DEFAULT_DB}
- Schema: {PROJECT_NAME}
- Warehouse: {TEAM_PREFIX}_{PROJECT}_WH
- All objects get a COMMENT describing their purpose

## Operational
- Search Snowflake docs before answering syntax questions from memory
- For multi-step tasks, use Plan Mode first (Ctrl/Cmd+Shift+P in Desktop, /plan in CLI)
- For destructive operations, show the SQL and ask for confirmation
- After any file write, verify the file exists
```
