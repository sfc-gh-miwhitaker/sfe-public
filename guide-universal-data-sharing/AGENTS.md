# Universal Data Sharing — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Documentation guide with companion SQL examples — no deployed Snowflake objects.

```
README.md                              → main guide narrative (start here)
sql/01_open_data_sharing.sql           → External consumer + PAT + external listing workflow
sql/02_open_table_format_sharing.sql   → Iceberg/Delta cross-cloud sharing
sql/03_collaboration_api_dcr.sql       → Multi-party clean room key calls
sql/04_universal_governance.sql        → Policy attachment for external engines
ELI5.md                                → plain-language companion
AGENTS.md                              → this file
```

## Conventions

- SQL examples use generic object names (`my_db`, `my_schema`, `test_ext_consumer`)
- Feature status (GA, Public Preview, Private Preview) stated explicitly on every claim
- Links to official docs provided for any feature where full SQL setup exceeds scope
- "Open Data Sharing" always capitalized as a product name
- No customer names, meeting references, or account identifiers
- Honest about preview limitations (e.g., single-region constraint during Private Preview)

## Key Commands

No deployment. To extend:
- Add new sharing pattern: create a new SQL file in `sql/`, add a section in `README.md`, update SKILL.md key files table.
- Update feature status: search README.md for the status badges table and update the relevant row.
