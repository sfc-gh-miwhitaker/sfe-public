# Example ~/.claude/CLAUDE.md Snippet

> Copy the section below into `~/.claude/CLAUDE.md` to make these standards always-on across all projects and sessions. Replace `{PLACEHOLDER}` values with your team's conventions.

```markdown
## SQL Standards
- Never use SELECT * in production code -- always project specific columns
- Sargable predicates only: never wrap columns in functions in WHERE clauses
- Use QUALIFY for window function filtering, not subquery wrapping
- Join keys must have matching types -- no implicit casts

## Security
- Never commit credentials, API keys, .env files, or account identifiers
- Use Snowflake secrets or environment variables for all credentials

## Naming Conventions
- Database: {DEFAULT_DB}
- Schema: {PROJECT_NAME}
- Warehouse: {TEAM_PREFIX}_{PROJECT}_WH
- All objects get a COMMENT describing their purpose

## Operational
- Search Snowflake docs before answering syntax questions from memory
- For multi-step tasks, use /plan mode first
- For destructive operations, show the SQL and ask for confirmation
```
