---
name: cowork-only-users
description: "Admin runbook for provisioning Snowflake CoWork-only users. Covers CORTEX_AGENT_USER role, ALLOWED_INTERFACES, CoWork object setup, single and bulk user provisioning. Use when working on this guide or helping an admin provision CoWork users."
---

# CoWork Admin Setup

## Purpose

Reference guide for Snowflake admins who need to give a group of users access to **only** Snowflake CoWork — the AI assistant at https://ai.snowflake.com — with no access to Snowsight or raw SQL.

## Architecture

No deployed Snowflake objects. The guide establishes this privilege structure:

```
COWORK_USER role
  ├── SNOWFLAKE.CORTEX_AGENT_USER  (database role — CoWork API only)
  ├── USAGE ON SNOWFLAKE INTELLIGENCE object
  └── USAGE ON each agent

Each user:
  ├── DEFAULT_ROLE = COWORK_USER
  ├── DEFAULT_WAREHOUSE = <warehouse>
  └── ALLOWED_INTERFACES = (SNOWFLAKE_INTELLIGENCE)
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Full guide: Quick Start, all 5 steps, gotchas, reference |
| `sql/setup_role.sql` | One-time role creation and grant setup |
| `sql/provision_user.sql` | Single user provisioning (annotated walkthrough) |
| `sql/provision_bulk.sql` | Bulk provisioning loop with temp table input |
| `sql/verify.sql` | Grant verification and end-to-end checks |
| `sql/revoke_access.sql` | Remove user or entire role |

## Adding a New Agent to CoWork

When an admin wants to give the CoWork users access to a new agent:

1. Make sure the agent exists: `SHOW AGENTS IN SCHEMA <db>.<schema>`
2. Add the agent to the CoWork object:
   ```sql
   ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
     ADD AGENT <db>.<schema>.<agent_name>;
   ```
3. Grant USAGE on the agent to the role:
   ```sql
   GRANT USAGE ON AGENT <db>.<schema>.<agent_name> TO ROLE COWORK_USER;
   ```
4. Verify: `DESCRIBE SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT`

No user-level changes needed — all members of `COWORK_USER` see it immediately.

## Snowflake Objects

This guide creates no persistent objects in SNOWFLAKE_EXAMPLE.
The admin creates these in their own account:
- Role: `COWORK_USER` (name is their choice)
- Object type: `SNOWFLAKE INTELLIGENCE` (the CoWork object — one per account)
- Privilege: `SNOWFLAKE.CORTEX_AGENT_USER` database role (built-in)

## Gotchas

- `ALLOWED_INTERFACES` cannot be set in `CREATE USER` — must use `ALTER USER` after creation
- If the CoWork object exists but an agent isn't added to it, users see **no agents** — not "all agents". Creating the CoWork object switches the account to curated mode.
- `CORTEX_USER` is granted to PUBLIC by default; `CORTEX_AGENT_USER` is the narrower alternative. Do not confuse them — granting `CORTEX_USER` gives full Cortex access.
- The bulk script uses `EXECUTE IMMEDIATE` with `QUOTE_STRING()` to handle email-format login names safely.
- `DEFAULT_WAREHOUSE` on the user is required even though CoWork-only users never see or pick a warehouse. Without it, agent tool queries fail.
