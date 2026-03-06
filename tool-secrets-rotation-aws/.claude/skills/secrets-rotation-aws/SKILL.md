---
name: secrets-rotation-aws
description: "Project-specific skill for Secrets Rotation Workbook. Snowflake Native Notebook for rotating key-pair and PAT credentials with AWS Secrets Manager. Use when working with this project, credential rotation, PAT management, or key-pair authentication."
---

# Secrets Rotation Workbook

## Purpose
Snowflake Native Notebook that demonstrates automated rotation of RSA key-pair credentials and Programmatic Access Tokens (PATs) for service accounts using AWS Secrets Manager. Creates a live example service user with full infrastructure.

## Architecture
```
deploy_all.sql
  └── Creates SNOWFLAKE_EXAMPLE.SECRETS_ROTATION schema
  └── Imports notebook from Git stage

secrets_rotation_workbook.ipynb (run cell-by-cell in Snowsight)
  ├── Section 1: Creates SFE_SVC_ROTATION_EXAMPLE (user, roles, policies)
  ├── Section 2: Pattern 1 -- Key-pair assignment + fingerprint verification
  ├── Section 3: Pattern 2 -- PAT creation, live rotation, before/after
  ├── Section 4: 10 monitoring queries (CREDENTIALS view + LOGIN_HISTORY)
  └── Section 5: Security checklist + gotchas

teardown_all.sql
  └── Drops ALL objects (user, roles, policies, notebook, schema)
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Creates schema, imports notebook from Git stage |
| `teardown_all.sql` | Complete cleanup of all objects |
| `secrets_rotation_workbook.ipynb` | Primary deliverable: interactive Snowflake Notebook |
| `diagrams.md` | Mermaid architecture diagrams (GitHub only) |

## Adding a New Monitoring Query

1. Open `secrets_rotation_workbook.ipynb` in a text editor or Snowsight
2. Add a new SQL cell in Section 4 (Monitoring) after the existing queries
3. Use `SNOWFLAKE.ACCOUNT_USAGE.CREDENTIALS` for PAT data or `LOGIN_HISTORY` for audit trails
4. Include a descriptive comment as the first line of the SQL cell
5. Ensure the query uses explicit columns (no `SELECT *`) and sargable predicates
6. If the query references the example user, use `SFE_SVC_ROTATION_EXAMPLE`

## Snowflake Objects
- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `SECRETS_ROTATION`
- Warehouse: `SFE_TOOLS_WH` (shared)
- Notebook: `SECRETS_ROTATION_WORKBOOK`
- User: `SFE_SVC_ROTATION_EXAMPLE` (TYPE=SERVICE)
- Roles: `SFE_SVC_ROTATION_ROLE`, `SFE_SVC_ROTATION_ROTATOR_ROLE`
- Network: `SFE_SVC_ROTATION_NETWORK_RULE`, `SFE_SVC_ROTATION_NETWORK_POLICY`
- Auth: `SFE_SVC_ROTATION_AUTH_POLICY`
- All objects have `COMMENT = 'TOOL: ... (Expires: 2026-04-05)'`

## Gotchas
- The deploy script only creates the schema and imports the notebook; it does NOT create the example user -- the notebook cells do that
- teardown_all.sql must drop objects from BOTH the deploy script (schema, notebook) and the notebook cells (user, roles, policies)
- Network policy and auth policy must be UNSET from the user before the user can be dropped
- PAT rotation requires key-pair auth -- cannot rotate a PAT from a PAT-authenticated session
- The notebook has markdown cells for AWS-side instructions (CLI, Lambda, IAM) since those cannot execute inside Snowflake
- `RESULT_SCAN(LAST_QUERY_ID())` in fingerprint verification cells requires running the DESC USER cell immediately before
- Auth policy and network rule are schema-scoped objects; network policy is account-scoped
