---
name: team-standards
description: "Team coding standards and operational best practices. Loaded automatically to enforce SQL quality, security, naming conventions, and session hygiene across all projects."
---

# Team Standards

## When to Use

This skill is always relevant. It encodes non-negotiable standards for SQL quality, security, naming, and operational discipline. Load it at the start of every session, and reload it after context compaction.

## SQL Standards

### Explicit Columns Only
- **Never use SELECT \*** in production or demo code
- Always project the specific columns needed
- Exception: `SELECT *` is acceptable in ad-hoc exploration during a conversation, but never in saved SQL files

### Sargable Predicates
- Never wrap columns in functions in WHERE clauses
- Wrong: `WHERE YEAR(order_date) = 2024`
- Right: `WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'`

### QUALIFY Over Subqueries
- Use QUALIFY for window function filtering instead of wrapping in a subquery
- Wrong: `SELECT * FROM (SELECT *, ROW_NUMBER() OVER (...) AS rn FROM t) WHERE rn = 1`
- Right: `SELECT ... FROM t QUALIFY ROW_NUMBER() OVER (...) = 1`

### Join Hygiene
- Join keys must have matching types -- no implicit casts
- No OR in join predicates -- use UNION ALL with deduplication instead

## Security Rules

- **Never commit** credentials, API keys, `.env` files, or account identifiers
- Use Snowflake secrets or environment variables for all credentials
- Never include account IDs, org names, or customer names in code or output
- Global gitignore only -- never commit `.gitignore` files to repos

## Naming Conventions

These patterns apply to Snowflake demo and project objects:

| Object | Pattern | Example |
|--------|---------|---------|
| Database | `SNOWFLAKE_EXAMPLE` | Shared across demos |
| Schema | `<PROJECT>` | `CAMPAIGN_ENGINE` |
| Warehouse | `SFE_<PROJECT>_WH` | `SFE_CAMPAIGN_ENGINE_WH` |
| Table (raw) | `RAW_<entity>` | `RAW_FEEDBACK` |
| Table (staging) | `STG_<entity>` | `STG_FEEDBACK` |
| Semantic View | `SV_<PROJECT>_<entity>` | `SV_CORTEX_FEEDBACK` |

All objects should include a COMMENT describing their purpose.

## Attribution

- Author line: `Pair-programmed by SE Community + Cortex Code` (never personal names)
- No customer names or meeting references in code

## Operational Best Practices

### Reload Context After Compaction
When a long session triggers context compaction (the conversation is summarized to free up space), critical instructions from CLAUDE.md and skills may be lost. After compaction:
1. Re-read the project's AGENTS.md
2. Re-read your user-level CLAUDE.md (`~/.claude/CLAUDE.md`)
3. Re-invoke any active skills that were loaded before compaction

If you notice the AI forgetting conventions mid-session, compaction likely happened. Re-state your core requirements or start a new session.

### New Session vs Continue
- **Start a new session** (`cortex` or `/new`) when switching to a different project or task
- **Continue the last session** (`cortex --continue`) when resuming the same task after a break
- Long sessions accumulate context debt -- if the AI starts drifting from your standards, a fresh session with a clear prompt often works better than correcting mid-conversation

### Search Docs Before Answering
- Always search Snowflake documentation before answering syntax, feature, or troubleshooting questions from memory
- In Cortex Code CLI: `cortex search docs "<specific query>"`
- Use specific queries: `"CREATE STREAM APPEND_ONLY syntax"` not `"streams"`
- Read all returned snippets before composing an answer

### Plan Before Acting
- For multi-step tasks, use `/plan` mode first to review the approach before execution
- For destructive operations (DDL, DML), always show the SQL and ask for confirmation
- For large refactors, break the work into focused prompts rather than one mega-prompt

## Common Patterns

### Starting a New Project
1. Create the project directory
2. Write an AGENTS.md with project name, database, schema, warehouse
3. Create `.claude/skills/` if the project needs project-specific skills
4. Start CoCo with `cortex -w /path/to/project`

### Reviewing AI Output
1. Read generated SQL before running it
2. Check for SELECT *, non-sargable predicates, missing COMMENTs
3. Verify naming conventions match the patterns above
4. Confirm no credentials or account IDs leaked into code
