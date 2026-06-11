# Connecting Copilot Studio to Snowflake — Project Instructions

## Architecture

Documentation-only guide (no deploy scripts, no Snowflake objects to create).

Split into three self-contained docs + a landing page:

- `README.md` — Landing page with decision framework and 4-pattern comparison
- `knowledge-source.md` — Pattern A: Snowflake as Knowledge Source (no-code)
- `cortex-analyst-connector.md` — Pattern B: Cortex Analyst via Power Automate Agent Flow
- `mcp-server.md` — Pattern C: MCP Server + Cortex Agent (recommended for production)

## Conventions

- Placeholder syntax: `<UPPERCASE_WITH_UNDERSCORES>` for values the reader must replace
- SQL uses ACCOUNTADMIN for security integrations, SYSADMIN for agent/MCP objects
- Each sub-doc is self-contained — a reader can follow one without reading the others
- Cross-links between docs use relative markdown links
- All patterns use Entra ID for auth — the Entra setup is documented in Pattern A and cross-referenced

## Key Commands

```bash
# Get Snowflake account identifier (hyphens, not underscores)
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();

# Get Azure token (client credentials flow)
curl -s -X POST "https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token" \
  -d "client_id=<CLIENT_ID>" -d "client_secret=<SECRET>" \
  -d "scope=<APP_ID_URI>/.default" -d "grant_type=client_credentials"

# Test MCP Server endpoint
curl -s -X POST \
  "https://<ORG-ACCOUNT>.snowflakecomputing.com/api/v2/databases/<DB>/schemas/<SCHEMA>/mcp-servers/<NAME>" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

## Critical Gotchas

- All patterns use Entra ID External OAuth — Copilot Studio cannot use Snowflake-native OAuth directly
- MCP Server URLs must use hyphens not underscores in hostnames
- `EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = 'sub'` for service principal flow (Pattern A/B)
- Pattern C uses Snowflake OAuth (OAUTH_CLIENT=CUSTOM) not External OAuth
- `OAUTH_USE_SECONDARY_ROLES = IMPLICIT` required for Pattern C
- Snowflake OAuth scope does NOT support `session:role-any` from Copilot — specify a single role
- OAUTH_REDIRECT_URI is a chicken-and-egg: create with placeholder, get real URL from Copilot, then ALTER

## Related Projects

- [`guide-connecting-claude-snowflake`](../guide-connecting-claude-snowflake/) — Same concept for Claude
- [`guide-mcp-auth`](../guide-mcp-auth/) — Comprehensive MCP auth for all AI clients
