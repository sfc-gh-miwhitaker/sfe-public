# Cortex AI Cost Controls — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Single-README narrative guide backed by standalone SQL scripts:

```
README.md              → The complete guide (reads cover-to-cover)
runaway-queries.md     → Extended deep-dive on the task-based runaway detection pattern
sql/                   → 7 standalone scripts (each runnable independently)
```

All SQL targets `SNOWFLAKE.ACCOUNT_USAGE` views. No objects are created in user databases
except the enforcement patterns in `sql/user_limits_*.sql` and `sql/account_budget.sql`,
which create objects in a user-defined schema.

## Conventions

- All queries use ACCOUNTADMIN or a role with IMPORTED PRIVILEGES on SNOWFLAKE database
- Credit column naming is inconsistent across views: `CREDITS`, `TOKEN_CREDITS`, `CREDITS_USED` — always comment which column to use
- `CORTEX_ANALYST_USAGE_HISTORY` uses `USERNAME`; all other views use `USER_NAME`
- SQL files are standalone — each opens with a comment block stating required role and caveats
- No SELECT * anywhere
- Sargable date predicates only (WHERE start_time >= DATEADD(...), never WHERE DATE(start_time) = ...)

## Key Commands

```bash
# No deploy script. Each sql/ file runs standalone in any SQL client.
# Validate all SQL compiles:
for f in sql/*.sql; do echo "--- $f ---"; done
```
