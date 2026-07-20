---
name: guide-powerbi-oauth
description: >
  Power BI + Snowflake OAuth configuration guide. Load for: powerbi oauth, powerbi sso,
  powerbi snowflake directquery, external oauth security integration, entra id snowflake,
  azure ad snowflake, login_name upn mismatch, power bi credentials error, oauth access token invalid
---

# guide-powerbi-oauth

## Purpose

Step-by-step guide for configuring Power BI to connect to Snowflake using OAuth SSO via Microsoft Entra ID (Azure AD). Covers DirectQuery vs Import mode selection, security integration setup, user provisioning, per-viewer identity for row-level security, and a complete troubleshooting error table.

## Architecture

Static guide — no Snowflake database or warehouse is created. The guide covers account-level security objects only:

```
Entra ID (Azure AD)
  → issues JWT token scoped to Snowflake audience URL
Power BI Desktop / Service (embedded Snowflake driver)
  → sends token in connection string
Snowflake External OAuth Security Integration
  → validates JWT signature via JWS keys URL
  → maps token UPN claim → Snowflake user LOGIN_NAME
  → creates session with user's DEFAULT_ROLE
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Full guide (14 sections: overview, DirectQuery, OAuth flow, setup steps, troubleshooting) |
| `sql/01_security_integration.sql` | `CREATE SECURITY INTEGRATION powerbi` — commercial + Gov variants |
| `sql/02_provision_users.sql` | User creation with correct `LOGIN_NAME = UPN`, bulk audit queries |
| `sql/03_validate.sql` | `login_history`, `DESC INTEGRATION`, token validation queries |
| `AGENTS.md` | Project-specific AI instructions |

## Extension Playbook: Adding a New OAuth Variant

To add support for a new scenario (e.g., Power BI Embedded, a different IdP):

1. Add a new commented-out `CREATE SECURITY INTEGRATION` block in `sql/01_security_integration.sql` with a distinct name (e.g., `powerbi_embedded`).
2. Add a new section to `README.md` under the "Advanced" group (Sections 9–12 pattern). Use an H2 heading, a summary table or bullet list, and the SQL block.
3. Add a row to the troubleshooting error table (Section 14) for any new error patterns.
4. Update the `description` frontmatter in this SKILL.md to include new trigger terms.

## Snowflake Objects

This guide does not create persistent Snowflake objects beyond the security integration. No schema, warehouse, or tables are needed.

| Object | Name | Notes |
|--------|------|-------|
| Security integration | `powerbi` | Account-level; created by admin |
| Security integration (Gov) | `powerbi_gov` | Commented out; uncomment if needed |
| Security integration (B2B) | `powerbi_b2b` | Documented in README Section 10 |

## Gotchas

- **Trailing slash on issuer URL is required.** `https://sts.windows.net/<tenant-id>/` — the trailing `/` must be present. If missing, authentication fails with "invalid access token" and the error is not obvious.
- **Both audience URL casing variants must be listed.** Microsoft may send either `Snowflake` or `snowflake` (lowercase). Include both in `EXTERNAL_OAUTH_AUDIENCE_LIST`.
- **Case sensitivity throughout.** All security integration parameter values are case-sensitive. A typo that changes casing = auth failure.
- **`login_name` vs `email_address` mapping.** `login_name` is safer — `email_address` fails silently if two users share an email.
- **Admin roles blocked by default.** `ACCOUNTADMIN`, `ORGADMIN`, `GLOBALORGADMIN`, `SECURITYADMIN` are blocked as default roles for Power BI OAuth sessions. Use a custom role.
- **DirectQuery + per-viewer identity** requires the Power BI Service dataset credential to be configured as OAuth2 with "report viewers use own identity" enabled — this is a separate step from the Desktop configuration.
- **Network policies cannot be scoped to the security integration** — they apply at account or user level only.
