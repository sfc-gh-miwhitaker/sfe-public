# Connecting Claude to Snowflake — Project Instructions

## Architecture

Documentation-only guide (no deploy scripts, no Snowflake objects to create). Rebuilt after Snowflake Summit 26 (June 1-4, 2026) around the thesis: **the problem was never the connection — it was missing governed context and the wrong direction of data flow.**

Four self-contained docs:

- `README.md` — Landing page: the two benchmark numbers (24%->86% accuracy; 51% fewer tokens), Summit 26 rebrand table, surface-first decision matrix
- `context-layer.md` — Why raw text-to-SQL is ~24% and how Horizon Context + Cortex Sense reach ~86%; semantic views, Semantic Studio, Autopilot, verified queries, eval gate
- `coco.md` — CoCo (formerly Cortex Code): Desktop, Cloud Agents, CLI, Agent SDK, MCP server + ACP, profiles/skills, envelopes; `cortex mcp serve` delegation; ADE-Bench cost story
- `governed-mcp.md` — Natoma MCP gateway + Claude-inside-Cortex inversion; recommended Option C (`cortex mcp serve` delegation), with a required accuracy prerequisite (semantic view + VQR + eval); legacy Snowflake OAuth (A) and Entra External OAuth (B) as last-choice options

## Summit 26 Rebrand (use "formerly X" on first mention)

- Snowflake Intelligence -> **Snowflake CoWork**
- Cortex Code -> **CoCo** (CLI binary still `cortex`; config still in `~/.snowflake/cortex/`)
- New: **Cortex Sense** (runtime context), **Horizon Context** (governed semantic layer), **Natoma** (MCP gateway acquisition)
- Anthropic $200M expansion: Claude runs inside Cortex AI, powering CoWork + CoCo

## Conventions

- Placeholder syntax: `<UPPERCASE_WITH_UNDERSCORES>` for values the reader must replace
- SQL uses ACCOUNTADMIN for integration creation, SYSADMIN for agent/MCP objects
- Each doc is self-contained; cross-links use relative markdown links
- Label preview / forward-looking features honestly (CoCo Desktop, Natoma gateway, Semantic Studio, Advanced Semantics were announced as preview/intent at Summit 26)
- Do NOT present raw MCP text-to-SQL as a recommended default — it is the legacy/convenience path

## Key Benchmarks (cite these)

- Accuracy: ~24% (agent alone) -> ~86% (with Cortex Sense context). Source: Snowflake Summit 26.
- Cost: CoCo 72.1% ADE-Bench vs Claude Code/Codex 65.1%; CoCo uses 51% fewer tokens + 8% less time than Claude Code on Opus 4.7. Source: Snowflake CoCo blog, Jun 2 2026.

## Key Commands

```bash
# CoCo: delegate to the data-native agent from Claude Desktop / Cursor
cortex mcp serve -c my_connection --bypass

# CoCo: install + connections
curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | sh
cortex connections list

# CoCo: publish skills + profile (RBAC-gated via stage READ)
cortex skill publish ./my-skills --to-stage @MY_DB.MY_SCHEMA.SKILLS_STAGE/skills/
cortex profile publish data-analyst --skill-stage @MY_DB.MY_SCHEMA.SKILLS_STAGE/skills/

# Legacy MCP: org-account identifier (hyphens, not underscores)
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();
```

## Critical Gotchas

- Legacy A/B: `OAUTH_USE_SECONDARY_ROLES = IMPLICIT` required; hostnames use hyphens not underscores
- Legacy B: issuer URL trailing slash must match exactly; HTTP 200 doesn't mean success (check JSON-RPC `error`)
- Snowflake MCP does NOT support DCR — `mcp-remote` auto-OAuth fails
- Any MCP text-to-SQL path inherits the ~24% ceiling without semantic views + verified queries
- CoCo SSO: `externalbrowser` needs existing Snowflake SSO; skills need stage READ grant
- CoCo `cortex mcp serve` needs `--bypass` so the calling client manages confirmations

## Related Projects

- [`guide-mcp-auth`](../guide-mcp-auth/) — Comprehensive MCP auth for all AI clients
- [`guide-agent-hardening`](../guide-agent-hardening/) — Agent governance playbook
- [`guide-external-access-playbook`](../guide-external-access-playbook/) — External access patterns
