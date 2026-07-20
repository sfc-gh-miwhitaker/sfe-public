# guide-powerbi-oauth — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Static guide — no Snowflake compute or data model required. The guide uses three SQL scripts that run in Snowsight:

```
sql/01_security_integration.sql  → CREATE SECURITY INTEGRATION powerbi
sql/02_provision_users.sql       → CREATE/ALTER USER with correct LOGIN_NAME
sql/03_validate.sql              → login_history + DESC INTEGRATION checks
```

All SQL is copy/paste into Snowsight. No warehouse or schema is created; this guide operates at the account/security level only.

## Conventions

- SQL filenames are prefixed `01_`, `02_`, `03_` to indicate execution order.
- All placeholder values use `<UPPER_SNAKE_CASE>` — never embed fake credentials.
- Entra tenant ID appears only in `01_security_integration.sql`.
- Commented-out SQL blocks (Gov cloud, secondary roles) are labeled with intent comments.

## Key Commands

```bash
# No deploy script needed — guide is doc-only with Snowsight-paste SQL scripts

# Verify README renders correctly
open guide-powerbi-oauth/README.md

# Check SQL files for any accidental credential leakage
grep -r 'password\|secret\|token' guide-powerbi-oauth/sql/
```
