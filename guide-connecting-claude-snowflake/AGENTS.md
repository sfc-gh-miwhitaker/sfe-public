# Connecting Claude to Snowflake — Project Instructions

## Architecture

Documentation-only guide (no deploy scripts, no Snowflake objects to create).

Three paths covered across two Claude surfaces:

- **Option A:** Claude Desktop + Snowflake OAuth → built-in connector (SSE endpoint)
- **Option B:** Claude Desktop + External OAuth via Entra ID → JSON config with Bearer token (REST endpoint)
- **Option C:** Claude Code / Cortex Code → Plugin routes to Cortex Code CLI with 35+ skills + profiles

Component chains:
- Options A/B: Entra ID / Snowflake OAuth → Security Integration → Cortex Agent → MCP Server → Claude Desktop
- Option C: Cortex Code Plugin → Cortex Code CLI → Snowflake connection (no MCP server needed)

## Conventions

- Placeholder syntax: `<UPPERCASE_WITH_UNDERSCORES>` for values the reader must replace
- SQL uses ACCOUNTADMIN for integration creation, SYSADMIN for agent/MCP objects
- Two distinct MCP URL formats for Options A/B:
  - Native connector (SSE): `/api/v2/mcp/servers/<db>.<schema>.<name>/sse`
  - REST/curl (JSON-RPC): `/api/v2/databases/<DB>/schemas/<SCHEMA>/mcp-servers/<NAME>`
- Option C has no URL — uses Cortex Code CLI connection directly

## Key Commands

```bash
# Option A/B: Get org-account identifier
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();

# Option B: Get Entra token (client credentials)
curl -s -X POST "https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token" \
  -d "client_id=<ID>" -d "client_secret=<SECRET>" \
  -d "scope=<APP_ID_URI>/.default" -d "grant_type=client_credentials"

# Option B: Validate token
SELECT SYSTEM$VERIFY_EXTERNAL_OAUTH_TOKEN('<token>');

# Option C: Install plugin
/plugin install snowflake-cortex-code

# Option C: Publish skills to stage
cortex skill publish ./my-skills --to-stage @MY_DB.MY_SCHEMA.SKILLS_STAGE/skills/

# Option C: Publish a profile
cortex profile publish data-analyst --skill-stage @MY_DB.MY_SCHEMA.SKILLS_STAGE/skills/
```

## Critical Gotchas

- `OAUTH_USE_SECONDARY_ROLES = IMPLICIT` required for Option A (bug-like behavior)
- Hostname underscores must be replaced with hyphens (Options A/B)
- Issuer URL trailing slash must match exactly (Option B)
- HTTP 200 does not mean success — check JSON-RPC error body (Options A/B)
- DCR (Dynamic Client Registration) is NOT supported by Snowflake MCP
- Option C: skills on stages require READ grant to the user's role
- Option C: org policy YAML overrides user-level config

## Related Projects

- [`guide-mcp-auth`](../guide-mcp-auth/) — Comprehensive MCP auth for all AI clients
- [`guide-agent-hardening`](../guide-agent-hardening/) — Agent governance playbook
- [`guide-external-access-playbook`](../guide-external-access-playbook/) — External access patterns
