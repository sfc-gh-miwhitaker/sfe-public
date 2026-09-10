![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--03--08-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake MCP Role Controls

This guide explains how primary and secondary roles are selected and restricted for Snowflake-managed MCP servers.

**Audience:** Snowflake security administrators and platform engineers configuring MCP clients.
**Created:** 2026-09-08 | **Expires:** 2027-03-08 | **Status:** ACTIVE

Pair-programmed by SE Community + Cortex Code

> **No support provided.** Reference only; validate before production use.

> **Scope:** The executable OAuth examples use a Snowflake OAuth custom-client integration. External OAuth can also authenticate MCP clients, but its token claims, role mapping, and secondary-role controls are configured with the external identity provider and External OAuth integration.

---

## Start Here

Choose the outcome first. The controls have similar names but operate at different layers.

| Requirement | Control | Recommended? |
| --- | --- | --- |
| Give an MCP client one predictable access boundary | Dedicated `MCP_ACCESS_ROLE`, `OAUTH_USE_SECONDARY_ROLES = NONE`, and OAuth `ALLOWED_ROLES_LIST` | Yes |
| Let the MCP session combine a small set of roles | `OAUTH_USE_SECONDARY_ROLES = IMPLICIT` plus a session policy with `ALLOWED_SECONDARY_ROLES` | Only when one role is insufficient |
| Advertise named primary roles to capable clients | `OAUTH_SCOPES_SUPPORTED` on the MCP server's schema, database, or account | Client-dependent |
| Let users choose or switch among approved roles | `OAUTH_ENABLE_ROLE_SELECTION` or `OAUTH_ANY_ROLE_MODE` | Preview; evaluate carefully |
| Limit which tools can be called | MCP server and underlying tool grants | Always required |

For most deployments, use the first row: one least-privileged access role, no secondary roles, and explicit grants to the MCP server and its tools.

## The Five Control Layers

An MCP session does not have one universal "role list." Its effective access is assembled from independent controls:

```text
MCP endpoint
  -> OAuth authenticates the Snowflake user
  -> OAuth scope or DEFAULT_ROLE selects the primary role
  -> OAuth integration permits or rejects that primary role
  -> OAuth integration decides whether secondary roles start active
  -> Session policy limits which secondary roles can remain active
  -> Snowflake RBAC checks the MCP server and each underlying tool
```

| Layer | Governs | Main controls |
| --- | --- | --- |
| MCP object | Connection and tool discovery | `USAGE ON MCP SERVER` |
| Tool object | Invocation of Agent, Search, Analyst, UDF, or procedure tools | Object-specific `USAGE` or `SELECT` grants |
| Primary role | The session's active role | OAuth scope, `DEFAULT_ROLE`, `OAUTH_SCOPES_SUPPORTED` |
| OAuth role boundary | Roles the OAuth client may use | `ALLOWED_ROLES_LIST`, `BLOCKED_ROLES_LIST` |
| Secondary roles | Additional active privilege sets | `OAUTH_USE_SECONDARY_ROLES`, session policy `ALLOWED_SECONDARY_ROLES` and `BLOCKED_SECONDARY_ROLES` |

> `ALLOWED_ROLES_LIST` and `ALLOWED_SECONDARY_ROLES` are not interchangeable. The first belongs to the OAuth integration; the second belongs to a session policy.

## Recommended Pattern: One MCP Access Role

Create a dedicated access role and grant only the MCP server, tool, and data privileges it needs. Configure Snowflake OAuth to accept that role and leave secondary roles disabled.

```sql
ALTER SECURITY INTEGRATION MCP_OAUTH_INTEGRATION
  SET OAUTH_USE_SECONDARY_ROLES = NONE;

ALTER SECURITY INTEGRATION MCP_OAUTH_INTEGRATION
  SET ALLOWED_ROLES_LIST = ('MCP_ACCESS_ROLE')
      OAUTH_ENABLE_ROLE_SELECTION = FALSE
      OAUTH_ANY_ROLE_MODE = DISABLE;

ALTER USER MCP_USER
  SET DEFAULT_ROLE = MCP_ACCESS_ROLE
      DEFAULT_WAREHOUSE = MCP_WAREHOUSE;
```

This gives the MCP client a predictable authorization context even when the user holds other roles. `ALLOWED_ROLES_LIST` does not grant the role and does not force the client to request it. The user must already hold the role; clients that request `session:role:all` use the user's `DEFAULT_ROLE`.

If role selection was previously enabled, revoke the user's existing delegated authorization before reconnecting. Role-selection consent is additive, and an older multi-role consent can otherwise outlive the configuration change:

```sql
ALTER USER MCP_USER
  REMOVE DELEGATED AUTHORIZATIONS
  FROM SECURITY INTEGRATION MCP_OAUTH_INTEGRATION;
```

Grant access at both levels:

```sql
GRANT USAGE ON MCP SERVER MCP_DB.MCP_SCHEMA.BUSINESS_MCP
  TO ROLE MCP_ACCESS_ROLE;

GRANT USAGE ON AGENT MCP_DB.MCP_SCHEMA.BUSINESS_AGENT
  TO ROLE MCP_ACCESS_ROLE;
```

Access to an MCP server does not automatically grant access to its tools. The role also needs the privileges required by every Agent, Cortex Search service, semantic view, function, procedure, table, and warehouse used by those tools.

## Exception Pattern: Allow Selected Secondary Roles

Use this only when the MCP workload cannot be represented by one access role. Snowflake OAuth can activate the user's default secondary roles when the session opens:

```sql
ALTER SECURITY INTEGRATION MCP_OAUTH_INTEGRATION
  SET OAUTH_USE_SECONDARY_ROLES = IMPLICIT;
```

Then use a session policy that acts as a ceiling:

```sql
CREATE SESSION POLICY SNOWFLAKE_EXAMPLE.SECURITY_POLICIES.MCP_SECONDARY_ROLE_POLICY
  ALLOWED_SECONDARY_ROLES = (MCP_ANALYST_ROLE, MCP_SEARCH_ROLE)
  BLOCKED_SECONDARY_ROLES = (SYSADMIN)
  COMMENT = 'Limits secondary roles available to MCP users';

ALTER USER MCP_USER
  SET SESSION POLICY SNOWFLAKE_EXAMPLE.SECURITY_POLICIES.MCP_SECONDARY_ROLE_POLICY;
```

Before creating or attaching that policy, inspect the account and user policy already in force. Snowflake allows one effective session policy, and a user-level policy overrides the account policy. Preserve existing idle-timeout, maximum-lifespan, and `AGENT_RESTRICTED_SESSION_SCOPE` settings in the replacement policy. The supplied SQL intentionally stops before attachment until that review is complete.

The effective secondary-role set is approximately:

```text
roles granted to the user
intersected with the user's default secondary roles
intersected with ALLOWED_SECONDARY_ROLES
minus BLOCKED_SECONDARY_ROLES
```

`BLOCKED_SECONDARY_ROLES` wins when a role is present in both lists. Blocking a role also prevents roles granted to that role from being activated as secondary roles. A session-policy change is enforced immediately, including in existing sessions.

### Important incompatibility

Snowflake does not allow this combination:

```text
OAUTH_USE_SECONDARY_ROLES = IMPLICIT
ALLOWED_ROLES_LIST = (...)
```

The OAuth allowlist can only be set when `OAUTH_USE_SECONDARY_ROLES = NONE`. Otherwise, automatically activated secondary roles could fall outside the OAuth allowlist. Snowflake does not document an `ALTER` operation that clears an existing OAuth role allowlist, so the exception script creates a separate integration without `ALLOWED_ROLES_LIST`. Do not convert an existing integration in place without validating the supported transition for your account.

## Primary Role and OAuth Scopes

OAuth scopes govern the primary role, not secondary roles.

| Scope | Meaning |
| --- | --- |
| `session:role:<ROLE_NAME>` | Use the named role as primary |
| `session:role:all` | Use the connecting user's `DEFAULT_ROLE`; despite the name, it does not activate all roles |
| `session:role-any` | Permit primary-role switching when the integration also enables any-role mode |

MCP servers advertise `session:role:all` by default. You can advertise named roles at the schema level:

```sql
ALTER SCHEMA MCP_DB.MCP_SCHEMA
  SET OAUTH_SCOPES_SUPPORTED =
    'session:role:MCP_ACCESS_ROLE,session:role:MCP_READONLY_ROLE';
```

This changes OAuth discovery, but client behavior still matters. A client that requests one of the named scopes gets that primary role. A client that requests `session:role:all` still gets the user's `DEFAULT_ROLE`. Claude is a documented example of the latter behavior.

## Preview: User-Selected and Switchable Roles

The following Snowflake OAuth custom-client capabilities are Preview as of the guide's creation date:

- `OAUTH_ENABLE_ROLE_SELECTION = TRUE` presents eligible roles during authorization when the client does not request a named role.
- `OAUTH_ANY_ROLE_MODE = ENABLE` permits `USE ROLE` when the client requests `session:role-any`.
- `OAUTH_ANY_ROLE_MODE = ENABLE_FOR_PRIVILEGE` additionally requires `USE_ANY_ROLE` on the integration.

Role selection is bounded by roles granted to the user and OAuth `ALLOWED_ROLES_LIST` / `BLOCKED_ROLES_LIST`. If a user consents to several roles, those roles form the session's role universe and may be used as primary or secondary roles.

Consent is additive: authorizing again can expand the role set but does not narrow it. Revoke delegated authorization before reducing a previously consented set:

```sql
ALTER USER MCP_USER
  REMOVE DELEGATED AUTHORIZATIONS
  FROM SECURITY INTEGRATION MCP_OAUTH_INTEGRATION;
```

Do not adopt this pattern solely to compensate for a client that always requests `session:role:all`. In that case, the simpler control is to set the correct `DEFAULT_ROLE` or provide separate MCP access patterns.

## Client Behavior

| Client behavior | Primary role result | Secondary-role result |
| --- | --- | --- |
| Requests `session:role:<ROLE>` | Named role, if granted and permitted | Controlled separately |
| Requests `session:role:all` | User's `DEFAULT_ROLE` | Not "all"; controlled by the integration |
| Requests `session:role-any` | Default or named initial role; switching allowed only when enabled | Controlled separately |

An OAuth consent screen may display wording such as "secondary roles = ALL" for a client requesting `session:role:all`. That label is cosmetic. Snowflake still enforces `OAUTH_USE_SECONDARY_ROLES`; with `NONE`, secondary roles are not activated.

## Validation

Reconnect the MCP client after changing OAuth settings. Then validate four separate questions:

1. Did the OAuth integration retain the intended role settings?
2. Does the user have the intended default role and warehouse?
3. Is the expected session policy attached?
4. Can the role discover the MCP server and invoke each intended tool, while unintended tools fail?

Use the statements in [`sql/04_validate_role_behavior.sql`](sql/04_validate_role_behavior.sql). For an end-to-end check, expose a tightly controlled diagnostic tool that returns `CURRENT_ROLE()` and `CURRENT_SECONDARY_ROLES()` or inspect query history generated by a test call. In the JSON returned by `CURRENT_SECONDARY_ROLES()`, verify both `roles` (roles actually active) and `value` (roles requested). Remove the diagnostic tool after validation.

## Troubleshooting

| Symptom | Likely cause | Check |
| --- | --- | --- |
| Authentication succeeds but the wrong role is active | Client requested `session:role:all` | Verify the user's `DEFAULT_ROLE` |
| OAuth authorization rejects the requested role | Role is not granted or is outside OAuth allow/block lists | `SHOW GRANTS TO USER` and `DESCRIBE INTEGRATION` |
| `ALLOWED_ROLES_LIST` cannot be set | Secondary roles are `IMPLICIT` | Set `OAUTH_USE_SECONDARY_ROLES = NONE` first |
| Unexpected privileges are available | Secondary roles are active | Inspect integration and session policy settings |
| MCP server appears but a tool call fails | MCP server grant exists, underlying tool grant does not | Check the Agent, Search, semantic view, function, procedure, table, and warehouse grants |
| Session fails during initialization | Default warehouse is missing or inaccessible | Set `DEFAULT_WAREHOUSE` and grant `USAGE` |
| Named scopes are advertised but ignored | Client does not request them | Use the correct `DEFAULT_ROLE` or a client that supports named scopes |

## Design Rules

- Prefer one dedicated role over combining several secondary roles.
- Treat separate MCP servers as tool/catalog boundaries, not as automatic execution identities.
- Keep direct `SYSTEM_EXECUTE_SQL` on a separate server with a dedicated least-privileged role when it is required.
- Grant the MCP access role only to intended users; do not grant it to `PUBLIC`.
- Re-test tool invocation after every role, OAuth, or session-policy change.
- Consider `IS_AGENTIC = TRUE` on a dedicated MCP OAuth integration when enhanced agent auditing or an agent restricted-session scope is part of the design.

## Development Tools

This guide is designed for AI-pair maintenance:

- `AGENTS.md` contains project-specific maintenance constraints.
- `.claude/skills/` explains the guide architecture, extension workflow, and gotchas.
- The ordered files in `sql/` keep configuration and validation examples reviewable.

## Related Guides

- [Snowflake-managed MCP server](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [Configure Snowflake OAuth for custom clients](https://docs.snowflake.com/en/user-guide/oauth-custom)
- [Snowflake sessions and session policies](https://docs.snowflake.com/en/user-guide/session-policies)
- [Overview of Access Control](https://docs.snowflake.com/en/user-guide/security-access-control-overview)

## External References

- [CREATE SECURITY INTEGRATION (Snowflake OAuth)](https://docs.snowflake.com/en/sql-reference/sql/create-security-integration-oauth-snowflake)
- [CREATE SESSION POLICY](https://docs.snowflake.com/en/sql-reference/sql/create-session-policy)
- [USE SECONDARY ROLES](https://docs.snowflake.com/en/sql-reference/sql/use-secondary-roles)
- [ALTER USER](https://docs.snowflake.com/en/sql-reference/sql/alter-user)
