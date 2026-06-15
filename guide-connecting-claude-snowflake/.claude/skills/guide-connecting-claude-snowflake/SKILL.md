---
name: guide-connecting-claude-snowflake
description: "Connect Claude to Snowflake the post-Summit-26 way: context over connection. Use when: Snowflake CoWork (formerly Snowflake Intelligence), CoCo (formerly Cortex Code), Cortex Sense, Horizon Context, Natoma MCP gateway, governed agentic access, Claude inside Cortex AI, cortex mcp serve delegation, semantic views accuracy, verified queries, why is text-to-SQL inaccurate, MCP cost, Entra ID External OAuth MCP, Claude Desktop Snowflake OAuth, enterprise SSO MCP."
---

# guide-connecting-claude-snowflake

## Purpose

Post-Summit-26 guide for putting Claude in front of Snowflake data. Core thesis: **the problem was never the connection — it was missing governed context and the wrong direction of data flow.** Raw conversational MCP text-to-SQL answers ~24% of hard questions and costs more; grounding in Horizon Context + Cortex Sense reaches ~86%. Steers readers to context-grounded, data-native, and centrally governed paths, and demotes raw MCP text-to-SQL to a caveated legacy appendix.

## Architecture

```
Principle 1: Bring the model to the data
  Claude inside Cortex AI -> powers CoWork (business) + CoCo (developer)

Principle 2: Ground every agent in governed context
  Horizon Context (defines truth) + Cortex Sense (delivers at query time) -> 24% to 86%

Principle 3: Govern tool-calls centrally
  Natoma MCP gateway -> identity, policy, audit per tool-call

Legacy (demoted): Claude Desktop -> MCP Server -> Cortex Agent text-to-SQL
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Thesis, two benchmark numbers, Summit 26 rebrand table, surface-first decision matrix |
| `context-layer.md` | Horizon Context + Cortex Sense; semantic views, Semantic Studio, Autopilot, verified queries, eval gate (the accuracy mechanism) |
| `coco.md` | CoCo platform: Desktop, Cloud Agents, CLI, Agent SDK, MCP+ACP, profiles/skills, envelopes, `cortex mcp serve` delegation, ADE-Bench |
| `governed-mcp.md` | Natoma gateway + Claude-in-Cortex inversion; legacy Snowflake OAuth (A) + Entra External OAuth (B) appendix |
| `AGENTS.md` | Project context for AI assistants |

## Summit 26 Rebrand

- Snowflake Intelligence -> **Snowflake CoWork**; Cortex Code -> **CoCo** (CLI still `cortex`, config in `~/.snowflake/cortex/`)
- New: **Cortex Sense** (runtime context), **Horizon Context** (governed semantic layer), **Natoma** (MCP gateway, acquisition)
- Anthropic $200M expansion: Claude runs inside Cortex AI powering CoWork + CoCo

## Extension Playbook

**To document a new IdP for the legacy Entra path (Okta, Cognito):**
1. Replace Entra Steps 1-3 with the IdP's app registrations
2. Update `EXTERNAL_OAUTH_TYPE` (`OKTA`, `CUSTOM`), issuer, JWKS, token endpoints, and user-mapping claim

**To add a new CoCo surface or integration:**
1. Confirm against the [CoCo blog](https://www.snowflake.com/en/blog/snowflake-coco-ai-coding-agent-modern-data-stack/) and `cortex-code` docs
2. For client delegation, use `cortex mcp serve` (server mode); for embedding, the Agent SDK

## Snowflake Objects

None created by this guide. All SQL is for the reader to execute in their own environment.

## Gotchas

- Any MCP text-to-SQL path inherits the ~24% accuracy ceiling without semantic views + verified queries — always pair with `context-layer.md`
- `OAUTH_USE_SECONDARY_ROLES = IMPLICIT` required for legacy Option A — other values silently fail
- Snowflake MCP does NOT support Dynamic Client Registration (DCR) — `mcp-remote` auto-OAuth fails
- Two URL formats: SSE for native connector, REST/JSON-RPC for curl/headers config
- External OAuth issuer URL is case-sensitive; trailing slash must match exactly
- HTTP 200 does not mean success — auth failures come as JSON-RPC errors in a 200 body
- Entra tokens expire ~60 min — plan for refresh in production
- CoCo: `externalbrowser` needs existing Snowflake SSO; skills on stages need READ grant; `cortex mcp serve` needs `--bypass`
- Label preview/forward-looking features (CoCo Desktop, Natoma gateway, Semantic Studio, Advanced Semantics) honestly
