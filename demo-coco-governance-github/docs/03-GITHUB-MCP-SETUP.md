# Step 3: GitHub MCP Setup — Secure Configuration

Now that governance is deployed, configure the GitHub MCP server.

## Two Patterns

| Pattern | Security | Setup Complexity | Recommended For |
|---------|----------|------------------|-----------------|
| **1Password CLI** | Secrets never touch disk | Moderate | Enterprise, teams with 1Password |
| **PAT in env file** | Token stored in file | Simple | Individual developers, testing |

## Pattern 1: 1Password CLI (Recommended)

### How It Works

1Password CLI (`op`) injects the GitHub PAT into the MCP server process at runtime.
The token never appears in any config file.

### Setup

1. Store your GitHub PAT in 1Password (e.g., in a "GitHub MCP" item)

2. Create the 1Password env file at `~/.config/op/mcp.env`:
```
GITHUB_PERSONAL_ACCESS_TOKEN=op://Personal/GitHub MCP/token
```

3. Add to `~/.snowflake/cortex/mcp.json`:
```json
{
  "mcpServers": {
    "github": {
      "command": "op",
      "args": [
        "run",
        "--env-file=/Users/YOUR_USERNAME/.config/op/mcp.env",
        "--no-masking",
        "--",
        "npx",
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
      }
    }
  }
}
```

See [reference/mcp-github-1password.json](../reference/mcp-github-1password.json) for the template.

### Verify

```bash
cortex
# Then type: /mcp
# GitHub server should show as connected
```

## Pattern 2: PAT in Environment (Simpler)

### Setup

1. Create `~/.snowflake/cortex/mcp.json`:
```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_YOUR_TOKEN_HERE"
      }
    }
  }
}
```

See [reference/mcp-github-pat.json](../reference/mcp-github-pat.json) for the template.

> **Security note:** The PAT is stored in the JSON file. Ensure `~/.snowflake/cortex/` has restrictive permissions (`chmod 700`).

### Verify

Same as Pattern 1: restart Cortex Code and check `/mcp`.

## Log the Connection

After configuring, record it in the audit log:

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB;

INSERT INTO MCP_CONNECTION_AUDIT
    (SERVER_NAME, AUTH_METHOD, TOOLSETS_ENABLED, TOOLSET_PROFILE, GOVERNANCE_VALIDATED, NOTES)
SELECT
    'github',
    '1password',  -- or 'pat'
    PARSE_JSON('["repos", "issues"]'),
    'standard',
    TRUE,
    'GitHub MCP configured after governance validation';
```

## Check Readiness

Ask the Governance Advisor: **"Am I ready now?"**

The advisor should now report **READY** if both governance and MCP are configured.

## Next Step

→ [Step 4: Toolset Scoping](04-TOOLSET-SCOPING.md)
