# Scenario: Restrict Who Can Use Cortex Code

**Goal:** Control which users and roles have access to Cortex Code — either broadly (disable all AI features) or selectively (specific roles or network locations).

---

## The access control hierarchy

```
ACCOUNTADMIN
  └── grants SNOWFLAKE.CORTEX_USER to roles/users
        └── roles with CORTEX_USER can call AI models
              └── optionally: restrict FURTHER with network policies
```

---

## CORTEX_USER — the master switch

`SNOWFLAKE.CORTEX_USER` is a database role on the `SNOWFLAKE` database. Any user or role **without** this privilege cannot access Cortex Code or other Cortex AI functions.

### Grant to a role

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE developer;
```

### Grant to a specific user

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO USER alice;
```

### Revoke (immediately disables Cortex Code access)

```sql
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE contractor_role;
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM USER alice;
```

---

## Scoped access pattern — per-team control

Create an intermediate role so you can grant/revoke at the team level:

```sql
CREATE ROLE cortex_code_users;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE cortex_code_users;

-- Add users to the team role
GRANT ROLE cortex_code_users TO USER alice;
GRANT ROLE cortex_code_users TO USER bob;

-- Remove team access without touching CORTEX_USER directly
REVOKE ROLE cortex_code_users FROM USER alice;
```

---

## Audit: who currently has access?

```sql
-- All roles that have CORTEX_USER
SELECT GRANTEE_NAME, GRANTED_TO, CREATED_ON
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE ROLE_NAME = 'CORTEX_USER'
  AND GRANTED_ON = 'DATABASE_ROLE'
  AND DELETED_ON IS NULL
ORDER BY CREATED_ON;

-- All users who have CORTEX_USER (directly or via a role)
SELECT DISTINCT u.NAME AS user_name
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS g ON u.NAME = g.GRANTEE_NAME
JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES r ON g.ROLE = r.GRANTEE_NAME
WHERE r.ROLE_NAME = 'CORTEX_USER'
  AND g.DELETED_ON IS NULL
  AND r.DELETED_ON IS NULL;
```

---

## Network policy — restrict by IP or location

> **Caution:** A network policy attached to a user blocks all Snowflake access for that user, not just Cortex Code. Use carefully.

```sql
-- Allow only corporate IP ranges
CREATE NETWORK POLICY corp_only_policy
  ALLOWED_IP_LIST = ('203.0.113.0/24', '10.0.0.0/8')
  COMMENT = 'Restrict Snowflake access to corporate network';

-- Apply to a specific user
ALTER USER contractor_alice SET NETWORK_POLICY = corp_only_policy;

-- Remove
ALTER USER contractor_alice UNSET NETWORK_POLICY;
```

---

## Budget management roles

Separate from who can *use* Cortex Code, these roles control who can *manage budgets*:

```
SNOWFLAKE.BUDGET_ADMIN     ← create, modify, delete any budget
SNOWFLAKE.BUDGET_CREATOR   ← create budgets in their own schemas
SNOWFLAKE.BUDGET_VIEWER    ← view budget status and spending history
```

```sql
-- Let FinOps team view all budgets
GRANT DATABASE ROLE SNOWFLAKE.BUDGET_VIEWER TO ROLE finops_role;

-- Let team leads create budgets for their own schemas
GRANT DATABASE ROLE SNOWFLAKE.BUDGET_CREATOR TO ROLE team_lead_role;

-- Per-budget instance delegation (fine-grained)
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!SET_ADMIN_ROLE(SYSTEM$ROLE_REFERENCE('team_lead_role'));
```

---

## Per-user daily credit limits — soft restriction

Instead of fully blocking access, per-user daily limits cap how many AI credits each user can consume in a rolling 24-hour window. When the cap is reached, Snowflake blocks further usage until enough time passes for the rolling window to drop below the limit.

```sql
-- Set account-wide default (applies to all users)
ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;

-- Override for a specific user
ALTER USER heavy_user SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 5;

-- Block a user from CLI entirely (while still allowing Snowsight)
ALTER USER contractor_alice SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 0;
```

> **Key difference from RBAC:** Per-user limits throttle rather than block outright. The user retains access until they exceed the cap, then regains access as the rolling window advances. See [set-a-limit.md](set-a-limit.md) for full details.

See `worksheets/per-user-limits.sql` for the impact analysis query, and `worksheets/notifications.sql` for proactive alerts before users hit their limit.

---

## Access control decision matrix

| Goal | Mechanism |
|------|-----------|
| Block a user from all AI features | `REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM USER ...` |
| Block a team | Revoke from their shared role |
| Throttle a user (not block) | Per-user daily limit (`ALTER USER ... SET CORTEX_CODE_*_DAILY_EST_CREDIT_LIMIT_PER_USER`) |
| Restrict to corporate network | Network policy on user or account |
| Let FinOps view but not modify budgets | `GRANT DATABASE ROLE SNOWFLAKE.BUDGET_VIEWER TO ROLE finops_role` |
| Let a team lead manage their own budget | `!SET_ADMIN_ROLE()` on the specific budget instance |

---

## Next steps

| | |
|--|--|
| Want to understand current spend before restricting | [understand-spend.md](understand-spend.md) |
| Want budget-based automatic actions alongside RBAC | [automate-response.md](automate-response.md) |
| Want to cap individual users without blocking them entirely | [set-a-limit.md](set-a-limit.md) — Option C |
| Want proactive alerts before a user is blocked by their daily limit | `worksheets/notifications.sql` |
