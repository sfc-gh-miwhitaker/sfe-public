# Team Standards

> This file is loaded at the start of every Cortex Code / Cursor / Claude Code session.
> It survives context compaction because it's re-read from the file system.

## Security
- Never commit credentials, API keys, .env files, or account identifiers to code
- Never include account IDs, org names, or customer names in code or output
- Use Snowflake secrets or environment variables for all credentials
- Warn before any operation that could expose sensitive data
- Scan code for credential patterns before commit

## SQL Quality
- Never use SELECT * in production code — always project specific columns
- Sargable predicates only: never wrap columns in functions in WHERE clauses
- Use QUALIFY for window function filtering, not subquery wrapping
- Join keys must have matching types — no implicit casts
- All CTEs must have meaningful names (not cte1, cte2)

## Destructive Operations
- Require explicit confirmation before DROP, DELETE, or TRUNCATE
- Show the SQL and ask "Proceed? (type 'yes' to confirm)" before executing
- For DELETE/UPDATE, show estimated row count first
- Never execute DROP on production schemas without double confirmation

## Code Quality
- Search Snowflake docs before answering syntax questions from memory
- For multi-step tasks, use /plan mode first
- Never assume a library is available — check package.json/requirements.txt first
- All SQL objects must include COMMENT

## Operational
- For long-running commands, use background mode
- Explain what each command does before executing
- If unsure about a request, ask clarifying questions

## Attribution
- No customer names or meeting references in code
- No internal project codenames in shared code
