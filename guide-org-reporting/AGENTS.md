# guide-org-reporting — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Single-file reference guide (README.md) covering SNOWFLAKE.ORGANIZATION_USAGE schema.
No deploy script, no Streamlit, no Snowflake objects to create.

## Conventions

- All SQL examples use explicit columns, time-bounded predicates, and sargable filters
- View names are UPPER_CASE; role names use UPPER_CASE
- Callout blocks use `> **` for warnings and gotchas

## Key Commands

```bash
# No deployment — this is a read-only reference guide
# To validate links:
grep -r 'docs.snowflake.com' guide-org-reporting/README.md
```
