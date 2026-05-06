---
name: guide-connecting-claude-snowflake
description: "Connect Claude to Snowflake via MCP OAuth, Entra ID External OAuth, or Cortex Code plugin with profiles. Use when: Entra ID MCP, External OAuth MCP, Claude Desktop Snowflake OAuth, Azure AD MCP server, enterprise SSO MCP, federated identity MCP, Zero Trust MCP, cortex code plugin, claude code snowflake, subagent cortex code, profiles, experience shaping."
---

# guide-connecting-claude-snowflake

## Purpose

Three-path guide for connecting Claude products (Desktop and Code) to Snowflake data. Covers MCP with Snowflake OAuth, MCP with Entra ID External OAuth, and the Cortex Code plugin with profiles for experience shaping. Educates on when each path is appropriate and how profiles bridge governance gaps in the MCP-only approach.

## Architecture

```
Surface 1: Claude Desktop (chat app)
  ├── Option A: Snowflake OAuth → built-in connector → MCP Server → Agent
  └── Option B: Entra ID JWT → headers config → MCP Server → Agent

Surface 2: Claude Code / Cortex Code (CLI agent)
  └── Option C: Plugin → Cortex Code CLI → 35+ skills + published profiles
```

Key differentiation:
- Options A/B give data access (question → answer pipe)
- Option C gives shaped experience (profiles control skills, prompts, envelopes per team)

## Key Files

| File | Role |
|------|------|
| `README.md` | Main guide — three paths, governance comparison, profiles walkthrough |
| `AGENTS.md` | Project context for AI assistants |
| `diagrams/` | Reserved for mermaid diagram source files |

## Extension Playbook: Adding a New IdP or Agent

**To add a new IdP (e.g., Okta, Cognito) for Option B:**
1. Replace Entra-specific Steps 1-3 with your IdP's equivalent app registrations
2. Update `EXTERNAL_OAUTH_TYPE` to `CUSTOM` or `OKTA`
3. Update issuer, JWKS, and token endpoints
4. Update user mapping claim to match your IdP's token format

**To add a new coding agent for Option C:**
1. Check [subagent-cortex-code](https://github.com/Snowflake-Labs/subagent-cortex-code) install table
2. Most agents work via `npx skills add snowflake-labs/subagent-cortex-code --copy --global`
3. Agent-specific routing rules may need manual activation (e.g., Cursor needs `.mdc` rule copy)

## Snowflake Objects

None created by this guide. All SQL is for the reader to execute in their own environment.

## Gotchas

- `OAUTH_USE_SECONDARY_ROLES = IMPLICIT` required for Option A — other values silently fail
- Snowflake MCP does NOT support Dynamic Client Registration (DCR) — `mcp-remote` auto-OAuth fails
- Two URL formats exist: SSE for native connector, REST for curl/headers config
- External OAuth issuer URL is case-sensitive; trailing slash must match exactly
- HTTP 200 does not mean success — auth failures come as JSON-RPC errors in a 200 body
- Entra tokens expire in ~60 min — plan for refresh in production
- Option C: skills on stages require READ grant — same RBAC model as data objects
- Option C: org policy YAML overrides user config — `auto` mode won't work if policy forces `prompt`
- Option C: `SNOWFLAKE.CORTEX_USER` database role may need explicit grant if revoked from PUBLIC
