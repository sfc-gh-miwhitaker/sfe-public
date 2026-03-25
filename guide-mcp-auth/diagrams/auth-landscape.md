# MCP Server Authentication Landscape

Which authentication method fits your scenario? Both paths converge at the same MCP endpoint -- the difference is how the Bearer token is obtained.

```mermaid
flowchart TD
    Start["Connect to Snowflake MCP Server"] --> Q1{"Environment?"}

    Q1 -->|"Dev / Testing"| PAT["Programmatic Access Token"]
    Q1 -->|"Production"| Q2{"Who authenticates?"}

    Q2 -->|"End users via browser"| OAuth["OAuth 2.0 + PKCE"]
    Q2 -->|"Service account"| Q3{"IdP requirement?"}

    Q3 -->|"Snowflake-native OK"| PAT
    Q3 -->|"Must use Entra/Okta"| ExtOAuth["External OAuth Integration"]

    PAT --> Header["Authorization: Bearer TOKEN"]
    OAuth --> Header
    ExtOAuth --> Header

    Header --> Endpoint["POST /api/v2/databases/DB/schemas/SCHEMA/mcp-servers/NAME"]
    Endpoint --> RBAC["Snowflake RBAC enforces access"]
    RBAC --> Tools["Tool discovery and invocation"]

    style ExtOAuth stroke-dasharray: 5 5
```

The dashed border on External OAuth indicates this path has limitations -- external IdP tokens for the managed MCP server are not yet fully productized. See Part 5 of the guide for workarounds.

## Decision Matrix

| Scenario | Auth Method | Token Lifetime | Rotation | Identity |
|---|---|---|---|---|
| Developer in Cursor/Claude Desktop | PAT | Configurable (days-months) | Manual or automated | Service identity |
| Streamlit / web app with login | OAuth + PKCE | ~10 minutes (access token) | Refresh token flow | End-user identity |
| Automated pipeline / CI | PAT with least-privilege role | Short-lived, rotated | AWS Secrets Manager / vault | Service identity |
| Multi-tenant SaaS | OAuth + PKCE with role scoping | ~10 minutes | Per-session | End-user + role identity |
| Enterprise with IdP mandate | External OAuth (limited) | Varies by IdP | IdP-managed | Federated identity |
