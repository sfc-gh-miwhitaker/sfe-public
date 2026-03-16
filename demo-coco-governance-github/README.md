![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--04--15-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Governed GitHub Integration for Cortex Code

> **DEMONSTRATION PROJECT - EXPIRES: 2026-04-15**
> This demo uses Snowflake features current as of March 2026.
> After expiration, a warning banner will be added to this README and deploy_all.sql.
> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

**Pair-programmed by:** SE Community + Cortex Code
**Created:** 2026-03-16 | **Expires:** 2026-04-15 | **Status:** ACTIVE

---

**Enable GitHub MCP integration for Cortex Code — only after governance is in place.**

This demo implements the **progressive unlock** pattern: GitHub tooling is blocked by default and only becomes available after organization governance is deployed and validated. A Cortex Agent acts as a governance advisor, answering "Am I ready to enable GitHub?"

---

## Brand New to GitHub or Cortex Code?

Start with the [Getting Started Guide](../guide-coco-setup/) -- it walks you through downloading the code and installing Cortex Code (the AI assistant that will help you with everything else).

## Prerequisites

- [ ] Completed the [general governance workshop](../guide-coco-governance-general/) (or equivalent knowledge)
- [ ] Cortex Code CLI installed and connected
- [ ] GitHub Personal Access Token (or 1Password CLI configured)
- [ ] ACCOUNTADMIN role access in Snowflake

## First Time Here?

1. **Deploy** -- Copy `deploy_all.sql` into Snowsight, click "Run All"
2. **Ask the advisor** -- In Snowflake Intelligence, ask `GOVERNANCE_ADVISOR`: "Am I ready to enable GitHub?"
3. **Configure governance** -- Follow [docs/02-GOVERNANCE-FIRST.md](docs/02-GOVERNANCE-FIRST.md)
4. **Enable GitHub MCP** -- Follow [docs/03-GITHUB-MCP-SETUP.md](docs/03-GITHUB-MCP-SETUP.md)
5. **Scope toolsets** -- Follow [docs/04-TOOLSET-SCOPING.md](docs/04-TOOLSET-SCOPING.md)
6. **Verify** -- Ask the advisor again: "Am I ready now?"
7. **Cleanup** -- Run `teardown_all.sql` when done

**Total setup time: ~30 minutes** (after general governance workshop)

## The Progressive Unlock Model

```
  No Governance             Governance Deployed          GitHub Enabled
  ─────────────             ───────────────────          ──────────────
  MCP: blocked              MCP: allowed (constrained)   MCP: active
  Agent: "not ready"        Agent: "ready to connect"    Agent: "connected"
  GitHub: unavailable       GitHub: configurable         GitHub: scoped toolsets
```

| Phase | Gate | What Unlocks |
|-------|------|--------------|
| 1. Deploy Snowflake objects | `deploy_all.sql` | Governance advisor agent |
| 2. Deploy managed-settings | IT deploys org policy | MCP connections allowed |
| 3. Configure GitHub MCP | User adds mcp.json | GitHub tools available |
| 4. Scope toolsets | Admin selects profile | Only approved GitHub ops |

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skill teaching the AI this project's patterns
- **Cortex Code in Snowsight** -- Open in a Workspace for AI-assisted development
- **Cursor** -- Open locally for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)

---

## What This Creates

| Object Type | Name | Purpose |
|---|---|---|
| Schema | `SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB` | Demo workspace |
| Warehouse | `SFE_COCO_GOVERNANCE_GITHUB_WH` | Demo compute |
| Table | `GOVERNANCE_POLICY_LOG` | Tracks governance config deployment events |
| Table | `MCP_CONNECTION_AUDIT` | Tracks MCP connection configurations |
| Function | `VALIDATE_GOVERNANCE_POLICY` | Checks governance readiness |
| Agent | `GOVERNANCE_ADVISOR` | Answers "Am I ready to enable GitHub?" |

## Future: Copilot-to-Cortex Bridge

This demo lays the groundwork for a future integration where GitHub Copilot delegates Snowflake-specific work to Cortex Code as a subagent. See [future/copilot-cortex-bridge.md](future/copilot-cortex-bridge.md) for the architecture.

---

## Complete Cleanup

```sql
-- Run in Snowsight:
-- teardown_all.sql
```

Removes: Agent, function, tables, schema, warehouse.
Preserves: SNOWFLAKE_EXAMPLE database, Git integration.

---

## Reference

**Snowflake Documentation:**
- [Cortex Code CLI Settings](https://docs.snowflake.com/en/user-guide/cortex-code/settings)
- [Cortex Code CLI Extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility)
- [Security Best Practices](https://docs.snowflake.com/en/user-guide/cortex-code/security)
- [CREATE AGENT](https://docs.snowflake.com/en/sql-reference/sql/create-agent)

**GitHub Documentation:**
- [About MCP in GitHub Copilot](https://docs.github.com/en/copilot/concepts/context/mcp)
- [GitHub MCP Server](https://github.com/github/github-mcp-server)

**Related Projects:**
- [General Governance Workshop](../guide-coco-governance-general/) -- Tool-agnostic governance fundamentals
- [Cortex Code Setup Guide](../guide-coco-setup/) -- Install and configure basics

---

## License

This demo project is provided as-is for educational purposes.

**Snowflake Terms:** [snowflake.com/legal](https://www.snowflake.com/legal/)
