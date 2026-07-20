---
name: guide-powerbi-oauth
description: >
  Power BI + Snowflake OAuth configuration guide. Load for: powerbi oauth, powerbi sso,
  powerbi snowflake directquery, external oauth security integration, entra id snowflake,
  azure ad snowflake, login_name upn mismatch, power bi credentials error, oauth access token invalid,
  scim provisioning snowflake, existing snowflake users oauth, login_name fix, scim secret token,
  aad provisioner, power bi microsoft account
---

# guide-powerbi-oauth

## Purpose

Recipe-format guide for Snowflake admins connecting Power BI to Snowflake using OAuth SSO via Microsoft Entra ID. Covers: DirectQuery vs Import mode decision, Snowflake security integration (Block A) + SCIM setup (Block B), SCIM bearer token generation, existing vs new user paths (LOGIN_NAME audit and fix), Power BI Desktop and Service configuration, and a full troubleshooting error table.

## Architecture

Static guide — no schema, warehouse, or tables created. Two account-level security objects and one SCIM role:

```
Microsoft Entra ID
  → SCIM sync creates Snowflake users with LOGIN_NAME = work email (via aad_provisioner role)
  → issues JWT token on Power BI login (scoped to Snowflake audience URL)

Power BI (embedded Snowflake driver)
  → passes JWT in connection string

Snowflake External OAuth Security Integration (powerbi)
  → validates JWT signature
  → maps UPN claim → user LOGIN_NAME
  → creates session with user's DEFAULT_ROLE

Snowflake SCIM Security Integration (aad_provisioning)
  → accepts user provisioning requests from Entra
  → runs as aad_provisioner role
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Full guide: intro, DirectQuery/Import decision, 4 setup steps, existing-user fork (Paths A/B/C), troubleshooting, special cases |
| `sql/01_security_integration.sql` | Block A (OAuth integration) + Block B (SCIM integration) + SCIM token generation + verification |
| `sql/02_provision_users.sql` | Existing user audit queries + LOGIN_NAME fix scripts (Fix 1: ALTER USER; Fix 2: ownership transfer) |
| `sql/03_validate.sql` | Post-connection validation: `login_history`, token verification |
| `AGENTS.md` | Project-specific AI instructions |

## Extension Playbook: Adding a New OAuth Variant

To add support for a new scenario (e.g., Power BI Embedded, a different IdP):

1. Add a new commented-out `CREATE SECURITY INTEGRATION` block in `sql/01_security_integration.sql` with a distinct name.
2. Add a new section to `README.md` under the "Special cases" heading. Use an H3, a one-sentence description, and the SQL block.
3. Add any new error patterns to the error table in the "When something goes wrong" section.
4. Update the `description` frontmatter in this SKILL.md to include new trigger terms.

## Snowflake Objects

| Object | Name | Notes |
|--------|------|-------|
| Security integration (OAuth) | `powerbi` | Account-level; trusts Entra for Power BI logins |
| Security integration (SCIM) | `aad_provisioning` | Accepts user sync from Entra; runs as `aad_provisioner` |
| Role | `aad_provisioner` | Owns SCIM-provisioned users; granted CREATE USER + CREATE ROLE |
| Security integration (B2B, optional) | `powerbi_b2b` | For guest users from other Entra tenants; uses `unique_name` claim |
| Security integration (Gov, optional) | `powerbi_gov` | Azure Government cloud; different audience URLs |

## Gotchas

- **SCIM Secret Token must be generated in Snowflake and pasted into the Microsoft tutorial.** The Microsoft setup asks for a Tenant URL and a Secret Token. The token comes from `SYSTEM$GENERATE_SCIM_ACCESS_TOKEN('AAD_PROVISIONING')` — it is not auto-populated anywhere. Missing this is the single most common hard stop on Step 2.
- **Trailing slash on issuer URL is required.** `https://sts.windows.net/<tenant-id>/` — the `/` at the end must be present. Missing it causes auth failures with a misleading error message.
- **Both audience URL casing variants must be listed.** Microsoft may send either `Snowflake` or `snowflake`. Both must be in `EXTERNAL_OAUTH_AUDIENCE_LIST`.
- **Existing users in Path C must have LOGIN_NAME fixed before OAuth will work.** SCIM cannot update users it doesn't own. Fix 1 (ALTER USER) works immediately. Fix 2 (GRANT OWNERSHIP) takes ~40 minutes for the automatic sync, or use "Provision on demand" in Entra for immediate effect.
- **Mixed-state accounts are common.** Some users may already have email-format LOGIN_NAME (Path B), others may not (Path C). Run the diagnostic query and handle each group separately — don't assume all users are in the same path.
- **`AAD` in SQL identifiers = Microsoft Entra ID.** `aad_provisioner` and `aad_provisioning` use the old Azure Active Directory branding. They are just identifiers — no different product involved.
- **Admin roles blocked by default.** `ACCOUNTADMIN`, `ORGADMIN`, `GLOBALORGADMIN`, `SECURITYADMIN` cannot be a user's `DEFAULT_ROLE` for Power BI OAuth sessions. Use a custom analyst/viewer role.
- **DirectQuery per-viewer identity requires a separate Power BI Service step.** The "Report viewers use own identities" checkbox in Power BI Service dataset credentials is independent of the Desktop connection setup — both must be configured.
