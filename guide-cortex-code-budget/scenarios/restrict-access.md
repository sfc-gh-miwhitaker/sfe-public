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

## Access control decision matrix

| Goal | Mechanism |
|------|-----------|
| Block a user from all AI features | `REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM USER ...` |
| Block a team | Revoke from their shared role |
| Restrict to corporate network | Network policy on user or account |
| Let FinOps view but not modify budgets | `GRANT DATABASE ROLE SNOWFLAKE.BUDGET_VIEWER TO ROLE finops_role` |
| Let a team lead manage their own budget | `!SET_ADMIN_ROLE()` on the specific budget instance |

---

## Next steps

| | |
|--|--|
| Want to understand current spend before restricting | [understand-spend.md](understand-spend.md) |
| Want budget-based automatic actions alongside RBAC | [automate-response.md](automate-response.md) |
