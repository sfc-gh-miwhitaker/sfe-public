# Path 1 — Snowflake-managed MCP server in VS Code Copilot Chat

Expose Cortex Search, Cortex Analyst, Cortex Agents, SQL execution, and custom UDFs as governed tools inside VS Code's GitHub Copilot Chat (Agent mode). Inference stays on Copilot's normal model. All Snowflake access is governed by RBAC and the user's `DEFAULT_ROLE`.

## What this path is

You create an `MCP SERVER` object in your Snowflake account and a security integration for OAuth. VS Code Copilot Chat connects to that endpoint over HTTP, discovers the tools the server exposes, and calls them when the model decides they're useful.

GA on Snowflake: November 4, 2025. GA on VS Code: requires VS Code 1.99 or later.

## When to use this path

- You want governed, auditable Snowflake tool access from Copilot Chat without changing models.
- You want Copilot to call Cortex Search across your indexed documents.
- You want Copilot to call Cortex Analyst for text-to-SQL against a semantic view.
- You want Copilot to invoke a Cortex Agent or run controlled SQL execution as a tool.

If you only need natural-language Snowflake help in your editor and don't need Copilot itself to call Snowflake tools, **Path 3** (CoCo CLI in the terminal) is faster to set up and gives you the full CoCo skill graph.

> **Accuracy depends on the semantic view, not the connection.** The `CORTEX_ANALYST_MESSAGE` tool turns natural language into SQL using the **semantic view** you point it at — so its accuracy is set by how well that view describes your data, plus any **verified queries** you've saved. Wiring up the MCP server is the quick part; a good semantic view is what makes the answers trustworthy. It's the same foundation every path in this guide shares — see [Where to learn the semantic-view foundation](README.md#where-to-learn-the-semantic-view-foundation). You don't need it to test the connection, but you do need it before business users rely on the results.

## Prerequisites

| | |
|---|---|
| **Snowflake** | Account with Cortex Agents enabled. Role with `CREATE MCP SERVER` in your target schema, plus the privileges below. Hostnames in the account URL must use **hyphens, not underscores** — Snowflake's MCP server has connection issues with underscored hostnames. |
| **Snowflake — auth** | Either an OAuth security integration (recommended) or a Programmatic Access Token (PAT) with the least-privileged role. |
| **VS Code** | Version 1.99 or later, with the GitHub Copilot Chat extension installed and signed in. Agent mode is required. |
| **Copilot policy** | If you are on Copilot Business or Copilot Enterprise, your admin must enable the **MCP servers in Copilot** policy (check your GitHub organization's Copilot settings, or ask your GitHub admin). Copilot Free / Pro / Pro+ users do not need this. |

Required Snowflake privileges on the MCP server's underlying tools:

| Tool type | Privilege required |
|---|---|
| `CORTEX_SEARCH_SERVICE_QUERY` | `USAGE` on the Cortex Search Service |
| `CORTEX_ANALYST_MESSAGE` | `SELECT` on the Semantic View (the MCP server only supports semantic views, not semantic models) |
| `CORTEX_AGENT_RUN` | `USAGE` on the Cortex Agent |
| `SYSTEM_EXECUTE_SQL` | The user's role must have access to the data the SQL touches. Set `read_only: true` to limit to SELECT. |
| `GENERIC` | `USAGE` on the UDF or stored procedure |

`USAGE` on the MCP server itself is also required to discover tools.

---

## Step 1: Create the MCP server

In a Snowsight worksheet, in the database and schema where the server should live:

> **Want to test on day one?** You don't need a Cortex Search service or a semantic view to get started — include just the `run_select` (`SYSTEM_EXECUTE_SQL`) tool block below and you can wire up and verify the connection immediately. Add the `product_search` and `revenue_analyst` tools once those objects exist (see [the shared foundation](README.md#where-to-learn-the-semantic-view-foundation)).

```sql
CREATE OR REPLACE MCP SERVER my_mcp
  FROM SPECIFICATION $$
tools:
  - name: "product_search"
    type: "CORTEX_SEARCH_SERVICE_QUERY"
    identifier: "MY_DB.PUBLIC.PRODUCT_DOCS_SEARCH"
    description: "Search across product documentation."
    title: "Product Search"

  - name: "revenue_analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "MY_DB.PUBLIC.REVENUE_SEMANTIC_VIEW"
    description: "Answer revenue questions using the revenue semantic view."
    title: "Revenue Analyst"

  - name: "run_select"
    type: "SYSTEM_EXECUTE_SQL"
    description: "Run a read-only SQL SELECT against the configured warehouse."
    config:
      read_only: true
      query_timeout: 120
      warehouse: "MY_WH"
$$;
```

Verify:

```sql
SHOW MCP SERVERS IN SCHEMA MY_DB.PUBLIC;
DESCRIBE MCP SERVER my_mcp;
```

> **Limits to know.** A single MCP server supports a maximum of 50 tools. Tool selection accuracy degrades as you approach the cap; split across multiple servers if you need more. Generic tool and SQL execution responses are truncated at 250 KB — narrow queries before they hit MCP, not after. Cortex Analyst returns SQL text, not query results — combine with `SYSTEM_EXECUTE_SQL` if you want execution.

## Step 2: Choose your auth path

### Option A — OAuth (recommended)

Create one security integration per MCP-using account. VS Code registers more than one OAuth callback URL, so use `OAUTH_ALTERNATE_REDIRECT_URIS`:

```sql
CREATE OR REPLACE SECURITY INTEGRATION my_mcp_oauth
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = 'https://vscode.dev/redirect'
  OAUTH_ALTERNATE_REDIRECT_URIS = (
    'http://localhost:33418/'
  );

SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('MY_MCP_OAUTH');
```

Note these from the result: `OAUTH_CLIENT_ID` and `OAUTH_CLIENT_SECRET`.

> **DCR is not supported.** Snowflake's managed MCP server does not implement Dynamic Client Registration. Each VS Code instance reuses the single security integration's client ID and secret; users still authenticate individually. Confirm the redirect URIs your VS Code build uses and add them to `OAUTH_ALTERNATE_REDIRECT_URIS` if they differ from the values above.

OAuth sessions use the user's `DEFAULT_ROLE`. Secondary roles are not honored. Set this for every user who will connect:

```sql
ALTER USER <username>
  SET DEFAULT_ROLE = '<mcp_access_role>'
      DEFAULT_WAREHOUSE = '<warehouse_name>';
```

### Option B — PAT bearer (fallback)

Generate a PAT in Snowsight: **Admin → Authentication → Programmatic Access Tokens**. Scope it to the least-privileged role that has the privileges from the prerequisites table. Treat the PAT like a password.

PAT auth is the simplest path for solo use and demos. OAuth is the supported path for any team rollout because it ties access to each user's identity.

## Step 3: Grant tool privileges

Grant the role the user will sign in as:

```sql
GRANT USAGE ON MCP SERVER MY_DB.PUBLIC.MY_MCP TO ROLE <mcp_access_role>;

GRANT USAGE ON CORTEX SEARCH SERVICE MY_DB.PUBLIC.PRODUCT_DOCS_SEARCH
  TO ROLE <mcp_access_role>;
GRANT SELECT ON SEMANTIC VIEW MY_DB.PUBLIC.REVENUE_SEMANTIC_VIEW
  TO ROLE <mcp_access_role>;
GRANT USAGE ON WAREHOUSE MY_WH TO ROLE <mcp_access_role>;
```

Verify the role has every privilege in the prerequisites table for each tool exposed.

## Step 4: Wire VS Code Copilot Chat

The MCP endpoint URL pattern is:

```
https://<org-account>.snowflakecomputing.com/api/v2/databases/<db>/schemas/<schema>/mcp-servers/<name>
```

Replace `<org-account>` with the hyphenated account identifier from:

```sql
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();
```

In your repo, create `.vscode/mcp.json` (workspace config). For secrets, see the note below.

> **Keep secrets out of git.** The OAuth config below contains a `client_secret`. Two safe options:
> - **Don't commit the workspace file:** add `.vscode/mcp.json` to your `.gitignore`.
> - **Use your user profile instead of the repo:** run **MCP: Open User Configuration** from the Command Palette (Cmd/Ctrl+Shift+P) to edit the user-profile `mcp.json`, which lives outside any repo and applies across all your workspaces.
>
> Better yet, the PAT option (Option B) avoids on-disk secrets entirely by prompting for the token at runtime via VS Code's `inputs` mechanism. VS Code's own MCP docs recommend not hardcoding secrets — prefer the input prompt or your user profile over a committed secret.

### Option A — OAuth config

```json
{
  "servers": {
    "snowflake-cortex": {
      "type": "http",
      "url": "https://<org-account>.snowflakecomputing.com/api/v2/databases/<DB>/schemas/<SCHEMA>/mcp-servers/MY_MCP",
      "oauth": {
        "client_id": "<OAUTH_CLIENT_ID>",
        "client_secret": "<OAUTH_CLIENT_SECRET>",
        "scope": "session:role:<mcp_access_role>"
      }
    }
  }
}
```

### Option B — PAT config

```json
{
  "inputs": [
    {
      "id": "snowflake_pat",
      "type": "promptString",
      "description": "Snowflake PAT for the MCP server",
      "password": true
    }
  ],
  "servers": {
    "snowflake-cortex": {
      "type": "http",
      "url": "https://<org-account>.snowflakecomputing.com/api/v2/databases/<DB>/schemas/<SCHEMA>/mcp-servers/MY_MCP",
      "headers": {
        "Authorization": "Bearer ${input:snowflake_pat}",
        "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN"
      }
    }
  }
}
```

VS Code prompts for the PAT once and caches it in the workspace inputs.

Save the file. VS Code shows a **Start** button at the top of the server list. Click it. On first connect with OAuth, a browser window opens for sign-in.

## Step 5: Verify in Copilot Chat

1. Open Copilot Chat.
2. Switch to **Agent** in the agent dropdown.
3. Click the tools icon at the top of the chat box. The server's tools (`product_search`, `revenue_analyst`, `run_select` in the example above) should appear.
4. Ask a question that should route to a tool — for example: *"Use product_search to find what the docs say about returns policy"*.
5. Confirm the tool call when prompted, then read the response.

Validate at the warehouse level:

```sql
SELECT QUERY_TYPE, QUERY_TEXT, ROLE_NAME, USER_NAME, START_TIME
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME > DATEADD(MINUTE, -10, CURRENT_TIMESTAMP())
  AND USER_NAME = '<your_user>'
ORDER BY START_TIME DESC;
```

You should see the Cortex Search / Cortex Analyst / SQL execution queries the MCP tool calls produced.

---

## Limits and known gotchas

- **DCR is not supported.** Use the OAuth security integration with `OAUTH_ALTERNATE_REDIRECT_URIS`, or PAT.
- **Underscore hostnames break MCP.** Always use the hyphenated `<org>-<account>` form.
- **OAuth sessions use `DEFAULT_ROLE` only.** Secondary roles are ignored even if the client requests `session:role:all` (the consent screen may show "secondary roles = ALL" cosmetically — Snowflake does not honor it).
- **Set `DEFAULT_WAREHOUSE`.** Sessions fail to initialize if it is null.
- **Cortex Analyst returns SQL only.** Pair with `SYSTEM_EXECUTE_SQL` for execution.
- **Tool count cap is 50.** Split into multiple servers if you need more. Accuracy of tool selection degrades as you approach the cap.
- **Response size cap is 250 KB** for `GENERIC` and `SYSTEM_EXECUTE_SQL` tools.
- **Failover groups don't replicate MCP server objects.** OAuth security integrations do replicate. If you fail over, recreate the MCP server objects on the secondary account.
- **Recursion limit is 10.** Don't configure agents that call tools that call back into other agents in a way that creates loops.

---

## Troubleshooting

### MCP server URL returns connection failure

**Symptom**: VS Code Copilot Chat reports the MCP server can't be reached.

Common causes:

1. **Underscore in the hostname.** Snowflake's MCP server has documented connection issues with hostnames containing underscores. Use the hyphenated form. Get it with:
   ```sql
   SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();
   ```
2. **Wrong path.** The endpoint is `/api/v2/databases/{db}/schemas/{schema}/mcp-servers/{name}` — note the `mcp-servers` literal, not `mcp_servers`.
3. **Network policy.** If a Snowflake network policy is in effect, the user's machine IP must be on it.

### "Insufficient privileges" when calling a tool

The role used in the OAuth session (or the role bound to the PAT) is missing one of the privileges from the prerequisites table above. `USAGE` on the MCP server is necessary but not sufficient — each tool's underlying object also requires its own privilege.

```sql
SHOW GRANTS TO ROLE <mcp_access_role>;
```

### OAuth sign-in completes but session uses wrong role

OAuth sessions use the user's `DEFAULT_ROLE`. Secondary roles are not honored. Set both `DEFAULT_ROLE` and `DEFAULT_WAREHOUSE`:

```sql
ALTER USER <username>
  SET DEFAULT_ROLE = '<mcp_access_role>'
      DEFAULT_WAREHOUSE = '<warehouse_name>';
```

If `DEFAULT_WAREHOUSE` is null, the session fails to initialize.

### "session:role:all" appears in the consent screen even though I disabled secondary roles

The display is cosmetic. Snowflake enforces the security integration setting (`OAUTH_USE_SECONDARY_ROLES = NONE`) regardless of what the client requests in scope. No additional roles are granted beyond `DEFAULT_ROLE`.

### VS Code keeps prompting for OAuth approval on every restart

Confirm `OAUTH_ALTERNATE_REDIRECT_URIS` includes every callback URL VS Code uses on your platform. Different VS Code builds (stable, Insiders, web) use different callbacks. Add them all to the integration.

### Cortex Analyst returns SQL but Copilot says "no data"

That is correct behavior. The Analyst tool returns SQL text only. To get query results, also expose `SYSTEM_EXECUTE_SQL` on the same MCP server and let Copilot chain the two.

### Tool response truncated

`GENERIC` and `SYSTEM_EXECUTE_SQL` responses are capped at 250 KB. Narrow the query or refine the search before it hits MCP.

### Tool count limit

A single MCP server caps at 50 tools. Split into multiple servers if you need more. Tool-selection accuracy degrades as you approach the cap; consider splitting at ~20 tools.

---

## References

- [Snowflake-managed MCP server (docs)](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [Integrate tools and data (Snowflake CoWork)](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence/integrate-tools)
- [GA release notes — Nov 4, 2025](https://docs.snowflake.com/en/release-notes/2025/other/2025-11-04-cortex-agents-mcp)
- [GitHub Copilot Chat: extending with MCP](https://docs.github.com/en/copilot/customizing-copilot/extending-copilot-chat-with-mcp)
- [VS Code: MCP servers](https://code.visualstudio.com/docs/copilot/customization/mcp-servers)
- [`guide-mcp-auth`](../guide-mcp-auth/) — comprehensive MCP authentication walkthrough across clients
