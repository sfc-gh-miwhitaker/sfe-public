# CoWork Admin Setup — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

This is a documentation-only guide — no Snowflake objects are deployed by this project itself.

The guide walks an admin through:

```
ACCOUNTADMIN
  └── Creates COWORK_USER role
        ├── Grants SNOWFLAKE.CORTEX_AGENT_USER (database role)
        ├── Grants USAGE ON SNOWFLAKE INTELLIGENCE object
        └── Grants USAGE ON AGENT(s)
  └── Creates users with ALLOWED_INTERFACES = (SNOWFLAKE_INTELLIGENCE)
  └── Grants COWORK_USER role to each user
```

Reference SQL files in `sql/` are standalone scripts — not a deploy sequence.

## Conventions

- Role name in examples: `COWORK_USER` (admin chooses their own name)
- Warehouse: placeholder `<your_warehouse>` — admin fills in their actual warehouse
- Login names: email-format strings (matches typical SSO/IdP pattern)
- All SQL examples use `IF NOT EXISTS` / `IF EXISTS` for safe re-runs
- `ALLOWED_INTERFACES` is set via `ALTER USER` after creation (can't be set in CREATE USER)

## Key Commands

```bash
# No deploy script — this is a reference guide
# All SQL files run standalone in Snowsight Worksheets → Run All

# Verify guide structure
ls -la sql/
```

SQL files (run individually, not as a sequence):
- `sql/setup_role.sql` — one-time role and grants setup
- `sql/provision_user.sql` — annotated single-user example
- `sql/provision_bulk.sql` — bulk provisioning loop
- `sql/verify.sql` — grant verification queries
- `sql/revoke_access.sql` — remove user or role
