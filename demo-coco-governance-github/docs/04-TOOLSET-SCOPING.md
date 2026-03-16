# Step 4: Toolset Scoping — Enable Only What You Need

GitHub MCP supports enabling or disabling specific groups of capabilities (toolsets). Fewer tools = better accuracy, fewer errors, smaller context window.

## Why Scope?

| Without Scoping | With Scoping |
|-----------------|--------------|
| All GitHub tools available | Only approved operations |
| AI may attempt unintended actions | AI focused on relevant tools |
| Larger context window consumption | Efficient token usage |
| Harder to audit | Clear boundary of allowed actions |

## Toolset Profiles

This demo includes three profiles:

### Minimal (Read-Only)

Best for: governance review, code browsing, issue reading.

```json
{
  "toolsets": "repos"
}
```

**What's available:** Repository listing, file reading, branch info.
**What's blocked:** Everything else (issues, PRs, write operations).

See [reference/toolset-profiles/minimal.json](../reference/toolset-profiles/minimal.json)

### Standard (Recommended)

Best for: daily development, issue tracking, PR reviews.

```json
{
  "toolsets": "repos,issues"
}
```

**What's available:** Repository access + issue read/write.
**What's blocked:** Pull request creation, code search, user management.

See [reference/toolset-profiles/standard.json](../reference/toolset-profiles/standard.json)

### Full (All Toolsets)

Best for: power users, CI/CD integration, admin workflows.

```json
{
  "toolsets": "all"
}
```

**What's available:** Everything the GitHub MCP server supports.
**What's blocked:** Nothing.

See [reference/toolset-profiles/full.json](../reference/toolset-profiles/full.json)

## Applying a Profile

Add `--toolsets` to your MCP server args. Example for the standard profile:

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
        "npx", "-y", "@modelcontextprotocol/server-github",
        "--toolsets", "repos,issues"
      ],
      "env": {
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
      }
    }
  }
}
```

## Log the Toolset Choice

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB;

UPDATE MCP_CONNECTION_AUDIT
SET TOOLSETS_ENABLED = PARSE_JSON('["repos", "issues"]'),
    TOOLSET_PROFILE = 'standard',
    NOTES = 'Toolset scoped to standard profile'
WHERE SERVER_NAME = 'github'
AND AUDIT_ID = (SELECT MAX(AUDIT_ID) FROM MCP_CONNECTION_AUDIT WHERE SERVER_NAME = 'github');
```

## Next Step

→ [Step 5: Progressive Unlock Test](05-PROGRESSIVE-UNLOCK-TEST.md)
