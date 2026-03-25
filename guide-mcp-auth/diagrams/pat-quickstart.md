# PAT Quick-Start Flow

Setup flow for connecting Cursor or Claude Desktop to a Snowflake MCP server using a Programmatic Access Token.

```mermaid
flowchart TD
    subgraph snowsight [Snowsight Setup]
        CreateMCP["CREATE MCP SERVER<br/>with tool specifications"]
        CreatePAT["Settings > Authentication ><br/>Programmatic Access Tokens"]
        GrantRole["GRANT USAGE ON MCP SERVER<br/>to PAT's role"]
        GrantTools["GRANT on underlying tool<br/>objects to role"]
    end

    subgraph client [Client Configuration]
        BuildURL["Build MCP endpoint URL"]
        WriteJSON["Create mcp.json with<br/>url + Authorization header"]
        TestCurl["Test with curl:<br/>tools/list request"]
    end

    subgraph verify [Verification]
        ToolList["Verify tool list returned"]
        ToolCall["Test tools/call with<br/>sample arguments"]
    end

    CreateMCP --> CreatePAT --> GrantRole --> GrantTools
    GrantTools --> BuildURL --> WriteJSON --> TestCurl
    TestCurl --> ToolList --> ToolCall
```

## URL Format

```
https://<ORG-ACCOUNT>.snowflakecomputing.com/api/v2/databases/<DB>/schemas/<SCHEMA>/mcp-servers/<NAME>
```

Use hyphens in the hostname, never underscores. Replace any `_` with `-` in your account identifier.

## mcp.json Structure

```json
{
    "mcpServers": {
        "Snowflake MCP Server": {
            "url": "https://<YOUR-ORG-YOUR-ACCOUNT>.snowflakecomputing.com/api/v2/databases/<DB>/schemas/<SCHEMA>/mcp-servers/<NAME>",
            "headers": {
                "Authorization": "Bearer <YOUR-PAT-TOKEN>"
            }
        }
    }
}
```

Never commit this file to version control. Add `mcp.json` to `.gitignore`.
