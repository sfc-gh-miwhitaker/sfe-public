# Client Connection Reference

Every major AI client connects to Snowflake's managed MCP server over HTTPS using the same endpoint URL and Bearer token pattern. The differences are config file location and JSON structure.

```mermaid
flowchart TD
    subgraph snowflake [Snowflake]
        MCPServer["MCP Server Object"]
        PAT["Programmatic Access Token"]
        Grants["USAGE + Tool Grants"]
    end

    subgraph endpoint [HTTPS Endpoint]
        URL["/api/v2/databases/DB/schemas/SCHEMA/mcp-servers/NAME"]
    end

    subgraph clients [AI Clients]
        Cursor[".cursor/mcp.json"]
        Claude["claude_desktop_config.json"]
        VSCode[".vscode/mcp.json"]
        CortexCode["~/.snowflake/cortex/mcp.json"]
        Windsurf["mcp_config.json"]
        CurlPython["curl / httpx"]
    end

    MCPServer --> URL
    PAT --> URL
    Grants --> URL

    URL --> Cursor
    URL --> Claude
    URL --> VSCode
    URL --> CortexCode
    URL --> Windsurf
    URL --> CurlPython
```

## Config File Quick Reference

| Client | Config Path (macOS) | Key Field | Auth Field |
|---|---|---|---|
| Cursor | `.cursor/mcp.json` (project) | `mcpServers.NAME.url` | `mcpServers.NAME.headers.Authorization` |
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `mcpServers.NAME.url` | `mcpServers.NAME.headers.Authorization` |
| VS Code + Copilot | `.vscode/mcp.json` (workspace) | `servers.NAME.url` | `servers.NAME.headers.Authorization` |
| Cortex Code | `~/.snowflake/cortex/mcp.json` | `mcpServers.NAME.url` | `mcpServers.NAME.headers.Authorization` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` | `mcpServers.NAME.serverUrl` | `mcpServers.NAME.headers.Authorization` |
| curl | N/A | `-X POST <url>` | `-H "Authorization: Bearer ..."` |

All clients send `Authorization: Bearer <PAT>` over HTTPS. The Snowflake MCP server is a standard HTTP MCP server -- no stdio bridge or local process needed.
