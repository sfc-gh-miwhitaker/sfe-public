# Future: Copilot-to-Cortex Bridge

> **Status: Conceptual / Roadmap** — This architecture is not yet buildable. It documents a future integration pattern.

## Vision

GitHub Copilot delegates Snowflake-specific work to Cortex Code, creating a bidirectional AI agent system:

```
Developer in VS Code
       │
       ▼
GitHub Copilot (primary agent)
       │
       ├─── General code tasks ──▶ Copilot handles directly
       │
       └─── Snowflake work ──▶ Cortex Code (subagent)
                                    │
                                    ├── SQL generation
                                    ├── Agent management
                                    ├── Semantic view queries
                                    └── Governance validation
```

## How It Would Work

### Architecture Option A: Copilot Extension

GitHub Copilot Extensions allow third-party agents to participate in Copilot conversations.

1. Cortex Code registers as a Copilot Extension
2. When Copilot encounters a Snowflake-specific task, it delegates to Cortex
3. Cortex executes with full Snowflake context (connections, tools, governance)
4. Results flow back through the Copilot conversation

**Requirements:** Copilot Extensions API, Cortex Code as HTTP service, OAuth flow.

### Architecture Option B: MCP Bidirectional

Both tools expose MCP servers to each other:

1. **Cortex → GitHub:** Already works (GitHub MCP server in mcp.json)
2. **Copilot → Cortex:** Cortex Code exposes an MCP server that Copilot connects to

This creates a symmetric integration where either tool can call the other.

**Requirements:** Cortex Code MCP server mode, Copilot MCP client support.

### Architecture Option C: Custom Copilot Agent

Configure GitHub Copilot to use Cortex Code as a "custom copilot" for specific workspaces:

1. `.github/copilot-instructions.md` references Cortex Code capabilities
2. Copilot delegates Snowflake queries to a Cortex Code API endpoint
3. Governance controls apply at both the Copilot and Cortex levels

**Requirements:** Custom copilot API, Cortex Code REST API mode.

## Governance Implications

The bidirectional bridge introduces new governance questions:

| Question | Governance Layer |
|----------|-----------------|
| Can Copilot call Cortex? | Organization policy (managed-settings) |
| Which Copilot workspaces have access? | Project policy (AGENTS.md) |
| What Snowflake operations can Copilot trigger? | User policy (CLAUDE.md) |
| Who audits cross-tool delegation? | Audit log (GOVERNANCE_POLICY_LOG) |

## When This Becomes Buildable

Watch for:
- [ ] GitHub Copilot Extensions GA with MCP support
- [ ] Cortex Code REST API or MCP server mode
- [ ] OAuth flow between GitHub and Snowflake for tool-to-tool auth
- [ ] Enterprise governance controls for cross-tool delegation

## Prototype: What You Can Try Today

While the full bridge isn't available, you can approximate it:

1. Use GitHub MCP in Cortex Code (this demo) for Cortex → GitHub
2. Use `.github/copilot-instructions.md` to teach Copilot about Snowflake patterns
3. Manually switch between tools when crossing domain boundaries

The governance patterns in this demo (progressive unlock, audit logging, toolset scoping) will apply directly when the full bridge becomes available.
