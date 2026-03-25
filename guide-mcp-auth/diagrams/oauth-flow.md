# OAuth 2.0 Authorization Code Flow with PKCE

Full sequence for authenticating an end user to a Snowflake MCP server. The role is specified in the OAuth scope at step 2 and remains bound to the token throughout the flow.

```mermaid
sequenceDiagram
    participant User as End User
    participant App as Your Application
    participant SF as Snowflake OAuth
    participant MCP as Snowflake MCP Server

    Note over App: Generate PKCE pair
    App->>App: code_verifier = random(32 bytes)
    App->>App: code_challenge = SHA256(code_verifier)

    User->>App: Click "Login with Snowflake"
    App->>SF: GET /oauth/authorize<br/>client_id, redirect_uri,<br/>code_challenge, scope=session:role:ANALYST_ROLE
    SF->>User: Snowflake login page
    User->>SF: Enter credentials + MFA
    SF->>App: Redirect with authorization code

    App->>SF: POST /oauth/token-request<br/>code, code_verifier, client_id, client_secret
    SF->>App: access_token + refresh_token<br/>scope: session:role:ANALYST_ROLE

    Note over App: Token is now bound to ANALYST_ROLE

    App->>MCP: POST /api/v2/.../mcp-servers/NAME<br/>Authorization: Bearer access_token<br/>method: tools/list
    MCP->>MCP: Validate token + role grants
    MCP->>App: Tool list (filtered by role)

    App->>MCP: POST .../mcp-servers/NAME<br/>method: tools/call<br/>name: my-tool, arguments: {...}
    MCP->>App: Tool result

    Note over App,MCP: Token expires (~10 min)
    App->>SF: POST /oauth/token-request<br/>grant_type=refresh_token
    SF->>App: New access_token
```

## Key Points

- **PKCE** prevents authorization code interception -- critical for web apps
- **Role in scope** means the token can only access what that role is granted
- **Refresh tokens** avoid forcing re-login on every token expiry
- **MFA** is enforced at the Snowflake login step, not at the MCP layer
