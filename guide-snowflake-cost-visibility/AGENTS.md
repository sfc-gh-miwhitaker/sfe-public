# Snowflake Cost Visibility — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

This guide covers four foundational cost visibility capabilities:

1. **Budget object** (`sql/budget_setup.sql`) — account-level predictive spend alerting
2. **ACCOUNT_USAGE queries** (`sql/account_usage_queries.sql`) — `METERING_DAILY_HISTORY`-based attribution
3. **Resource monitors** (`sql/resource_monitors.sql`) — warehouse-level credit guardrails
4. **AI_FUNCTIONS_USER RBAC** (`sql/ai_functions_user_rbac.sql`) — new BU access control pattern

The guide (`README.md`) is the primary deliverable. SQL files are the leave-behind artifacts — each file
is self-contained and copy-paste ready.

## Conventions

- No customer names or specific credit amounts anywhere in committed files
- Role names use generic patterns: `ANALYST_ROLE`, `DATA_ENG_ROLE`, `NEW_BU_ROLE`, `TRUSTED_ROLE`
- Email addresses use placeholder domains: `admin@example.com`
- SQL files include comment blocks explaining what to substitute before running

## Key Commands

```bash
# Verify file list
ls -la sql/

# Check for any customer name leakage
# Check for any customer name leakage before committing:
# grep -ri "<customer-name>" . --include="*.md" --include="*.sql"
```
