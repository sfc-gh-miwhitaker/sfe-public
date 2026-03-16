---
name: demo-coco-governance-github
description: "Governed GitHub MCP integration for Cortex Code. Progressive unlock pattern where governance gates external tool connections. Triggers: github governance, MCP governance, progressive unlock, governed github, managed-settings MCP, github mcp setup, copilot cortex bridge."
---

# Governed GitHub Integration for Cortex Code

## Purpose

Demonstrate the progressive unlock pattern: GitHub MCP integration for Cortex Code is gated by organization governance. A Cortex Agent validates governance readiness before GitHub tools become available. Includes future architecture for GitHub Copilot delegating Snowflake work to Cortex.

## Architecture

```
IT Admin                          Developer
   │                                 │
   ▼                                 │
managed-settings.json                │
(MDM deploy)                         │
   │                                 │
   ▼                                 │
MCP policy: allowed ─────────────────▶ mcp.json (GitHub MCP)
                                     │
                                     ▼
                              Toolset scoping
                              (minimal/standard/full)
                                     │
                                     ▼
GOVERNANCE_ADVISOR ◄──── "Am I ready?" queries
   │
   ▼
VALIDATE_GOVERNANCE_POLICY (UDF)
   │
   ▼
GOVERNANCE_POLICY_LOG + MCP_CONNECTION_AUDIT
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Single entry point for Snowsight deployment |
| `sql/01_setup/01_create_demo_objects.sql` | Schema, warehouse creation |
| `sql/01_setup/02_create_audit_tables.sql` | Governance and MCP audit tables |
| `sql/01_setup/03_create_governance_advisor.sql` | CREATE AGENT DDL |
| `sql/01_setup/04_create_policy_check_function.sql` | VALIDATE_GOVERNANCE_POLICY UDF |
| `docs/02-GOVERNANCE-FIRST.md` | Progressive unlock concept (the thesis) |
| `docs/03-GITHUB-MCP-SETUP.md` | Secure GitHub MCP configuration |
| `reference/managed-settings-mcp-enabled.json` | Org policy enabling MCP |
| `reference/mcp-github-1password.json` | 1Password-secured GitHub MCP template |

## Adding a New Governance Check

1. Add a new validation query to `VALIDATE_GOVERNANCE_POLICY` function
2. Insert a row into `GOVERNANCE_POLICY_LOG` for the new check type
3. Update the agent's `instructions.orchestration` to reference the new check
4. Recreate the agent: `CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$...$$;`
5. Test: ask the advisor about the new governance dimension
6. Update `docs/02-GOVERNANCE-FIRST.md` with the new check

## Adding a New MCP Toolset Profile

1. Create `reference/toolset-profiles/<profile-name>.json` with enabled toolsets
2. Add the profile to the comparison table in `docs/04-TOOLSET-SCOPING.md`
3. Insert a row into `MCP_CONNECTION_AUDIT` for the new profile
4. Update `VALIDATE_GOVERNANCE_POLICY` to recognize the new profile

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB` |
| Warehouse | `SFE_COCO_GOVERNANCE_GITHUB_WH` |
| Agent | `GOVERNANCE_ADVISOR` |
| Function | `VALIDATE_GOVERNANCE_POLICY(VARCHAR)` |
| Table | `GOVERNANCE_POLICY_LOG` |
| Table | `MCP_CONNECTION_AUDIT` |

## Gotchas

- managed-settings.json is OS-specific: macOS `/Library/Application Support/Cortex/`, Linux `/etc/cortex/`
- mcp.json lives at `~/.snowflake/cortex/mcp.json` (not in the project)
- GitHub MCP server is `@modelcontextprotocol/server-github` (npm package)
- Toolset scoping uses `--toolsets` flag on the GitHub MCP server, not managed-settings
- The progressive unlock is conceptual (governance awareness), not a hard technical gate
- SHOW AGENTS not SHOW CORTEX AGENTS
