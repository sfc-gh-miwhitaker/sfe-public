# Connecting Claude to Snowflake — Project Instructions

## Architecture

Documentation-only guide (no deploy scripts, no Snowflake objects to create).

Split into two self-contained docs + a landing page:

- `README.md` — Landing page with decision flowchart and governance comparison
- `mcp-oauth.md` — Claude Desktop path: Snowflake OAuth (Option A) + Entra ID External OAuth (Option B)
- `cortex-code-plugin.md` — CLI path: Cortex Code plugin + profiles + experience shaping (Option C)

## Conventions

- Placeholder syntax: `<UPPERCASE_WITH_UNDERSCORES>` for values the reader must replace
- SQL uses ACCOUNTADMIN for integration creation, SYSADMIN for agent/MCP objects
- Each sub-doc is self-contained — a reader can follow one without reading the other
- Cross-links between docs use relative markdown links

## Key Commands

```bash
# Options A/B: Get org-account identifier
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();

# Option B: Get Entra token
curl -s -X POST "https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token" \
  -d "client_id=<ID>" -d "client_secret=<SECRET>" \
  -d "scope=<APP_ID_URI>/.default" -d "grant_type=client_credentials"

# Option C: Install plugin
/plugin install snowflake-cortex-code

# Option C: Publish skills + profile
cortex skill publish ./my-skills --to-stage @MY_DB.MY_SCHEMA.SKILLS_STAGE/skills/
cortex profile publish data-analyst --skill-stage @MY_DB.MY_SCHEMA.SKILLS_STAGE/skills/
```

## Critical Gotchas

- Options A/B: `OAUTH_USE_SECONDARY_ROLES = IMPLICIT` required, hostnames use hyphens not underscores
- Option B: Issuer URL trailing slash must match exactly, HTTP 200 doesn't mean success
- Option C: `externalbrowser` authenticator requires existing Snowflake SSO config, skills need stage READ grant
- DCR (Dynamic Client Registration) is NOT supported by Snowflake MCP

## Related Projects

- [`guide-mcp-auth`](../guide-mcp-auth/) — Comprehensive MCP auth for all AI clients
- [`guide-agent-hardening`](../guide-agent-hardening/) — Agent governance playbook
- [`guide-external-access-playbook`](../guide-external-access-playbook/) — External access patterns
