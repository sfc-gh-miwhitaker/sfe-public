# GitHub-Powered Project Tooling for Cortex Code

<!-- DEMO_STATUS: ACTIVE | Expires: 2026-04-15 -->

![Expires](https://img.shields.io/badge/Expires-2026--04--15-yellow)

> [!CAUTION]
> **No support provided.** This content is for reference only. Review and validate before applying to any production workflow.

Same `AGENTS.md`, same skill, both surfaces. Store your project standards in a GitHub repo. Cortex Code reads them automatically in CLI (from your clone) and in Snowsight (from a Git-connected workspace). GitHub's collaboration features become your team management layer. Intune adds the enterprise wrapper.

**Time:** ~30 minutes | **Result:** Working project tooling on CLI + Snowsight

## Quick Start

**Deploy in Snowsight (no clone needed):**
Copy [`deploy_all.sql`](deploy_all.sql) into a Snowsight worksheet and click **Run All**.

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) demo-coco-governance-github
cd sfe-public/demo-coco-governance-github && cortex
```

The standards in `AGENTS.md` are already active. Try: *"Write a query that finds the top 5 customers by total order amount"*

## Three Acts

| Act | What | Doc |
|-----|------|-----|
| **1. Project Tooling** | `AGENTS.md` + custom skill work in both CLI and Snowsight | [docs/01-PROJECT-TOOLING.md](docs/01-PROJECT-TOOLING.md) |
| **2. GitHub Team Management** | PRs, Issues, branch protection, and GitHub MCP for team-wide standards | [docs/02-GITHUB-TEAM-MANAGEMENT.md](docs/02-GITHUB-TEAM-MANAGEMENT.md) |
| **3. Intune Enterprise** | `managed-settings.json` via MDM for org-level enforcement | [docs/03-INTUNE-ENTERPRISE.md](docs/03-INTUNE-ENTERPRISE.md) |

## What's in the Repo

### Project tooling (the core deliverable)

| File | Purpose |
|------|---------|
| `AGENTS.md` | Project standards -- loaded automatically by Cortex Code on both surfaces |
| `.claude/skills/.../SKILL.md` | SQL review procedure -- invoked on demand |

### Supporting SQL

| Object | Purpose |
|--------|---------|
| Schema: `SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB` | Demo workspace |
| Warehouse: `SFE_COCO_GOVERNANCE_GITHUB_WH` | Compute for sample queries |
| Tables: `CUSTOMERS`, `ORDERS`, `PRODUCTS` | Sample data to test standards against |

### Reference configs

| File | Purpose |
|------|---------|
| `reference/mcp-github-1password.json` | GitHub MCP config with 1Password (recommended) |
| `reference/mcp-github-pat.json` | GitHub MCP config with PAT |
| `reference/managed-settings-mcp-enabled.json` | Org-level managed settings template |
| `reference/intune-config.json` | Intune deployment config for managed-settings |

### Diagrams

| File | Shows |
|------|-------|
| `diagrams/dual-surface.md` | CLI and Snowsight reading the same AGENTS.md |
| `diagrams/github-team-flow.md` | Team onboarding and standards evolution cycle |
| `diagrams/governance-stack.md` | Three-layer stack: project, team, enterprise |

## Prerequisites

- ACCOUNTADMIN role access (for `deploy_all.sql`)
- Cortex Code CLI installed ([install guide](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli))
- Cortex Code enabled in Snowsight ([docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-snowsight))
- GitHub account (for Act 2 MCP setup)

## Development Tools

This project is pair-programmed with AI coding assistants. The following files configure their behavior:

| File | Purpose |
|------|---------|
| `AGENTS.md` | Project context and standards -- loaded automatically by Cortex Code, Cursor, and Claude Code |
| `.claude/skills/demo-coco-governance-github/SKILL.md` | SQL review procedure skill -- invoked on demand for structured code review |

These files are the demo's primary deliverable. They demonstrate how project tooling in a Git repo serves both CLI and Snowsight surfaces.

## Cleanup

Run `teardown_all.sql` in Snowsight to remove all Snowflake objects.

---

*Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-15*
