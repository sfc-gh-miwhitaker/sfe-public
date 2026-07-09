---
name: guide-claude-code-cortex-redirect
description: >
  Redirect Claude Code CLI and Anthropic SDK inference to Snowflake Cortex.
  Load for: Claude Code cortex redirect, ANTHROPIC_BASE_URL Snowflake, SDK proxy
  Cortex API, cortex REST API redirect, route claude code through snowflake.
metadata:
  type: project
---

# guide-claude-code-cortex-redirect

## Purpose

How to point the `claude` CLI (Claude Code) and Anthropic SDK clients at Snowflake's
Cortex REST API instead of Anthropic directly — so all inference runs inside the
Snowflake perimeter, billed to Snowflake, and governed by RBAC.

## Architecture

```
claude CLI / anthropic SDK client
        |
        | ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN
        v
https://<account>.snowflakecomputing.com/api/v2/cortex/v1/messages
        |
        | Snowflake Cortex REST API (Anthropic-compatible Messages endpoint)
        v
Claude model (running inside Snowflake perimeter)
```

Two endpoint choices:
- Messages API `/api/v2/cortex/v1/messages` — Anthropic-spec, Claude models only
- Chat Completions `/api/v2/cortex/v1/chat/completions` — OpenAI-spec, all models

## Key Files

| File | Role |
|------|------|
| `README.md` | Overview, routing decision, prerequisites |
| `claude-code-redirect.md` | Claude Code CLI setup (env vars, settings.json) |
| `sdk-redirect.md` | Python + Node SDK redirect patterns |
| `AGENTS.md` | Project-specific AI tooling instructions |

## Snowflake Objects

None — guide only, no Snowflake objects deployed.

Auth required: Snowflake PAT (Programmatic Access Token) or OAuth token.
Role required: Default role must have `SNOWFLAKE.CORTEX_USER` (public by default).

## Extension Playbook

### How to add a new SDK example (Python, Node, curl)

1. Add the new language to `sdk-redirect.md` under the relevant section (Messages API
   or Chat Completions).
2. Follow the same pattern as existing examples: show how to override the auth header
   to send `Authorization: Bearer` instead of `x-api-key` (the critical difference
   from hitting Anthropic directly).
3. Include an async version if the SDK supports it.
4. Add a Verify step using the query from the Verification section.

## Gotchas

- `ANTHROPIC_API_KEY` sends credentials as `x-api-key` header — Snowflake rejects this.
  Use `ANTHROPIC_AUTH_TOKEN` instead (sends as `Authorization: Bearer`).
- Base URL for Messages API is `…/api/v2/cortex` (no `/v1`); the SDK appends `/v1/messages`.
  For Chat Completions use `…/api/v2/cortex/v1` (SDK appends `/chat/completions`).
- Model names must be bare (no date suffixes): `claude-sonnet-4-6`, not `claude-sonnet-4-5-20250514`.
- Claude Code Desktop VS Code extension does not yet support `ANTHROPIC_BASE_URL` (CLI only).
- `claude-haiku-4-5` IS available in the REST API (GA). Confusion comes from some regional AI_COMPLETE availability tables; it is present in the REST API billing table.
- `claude-opus-4-8`, `claude-fable-5`, `claude-sonnet-5` are available via REST API but are Preview — not suitable for production workloads per Snowflake Preview Terms.
- `claude-opus-4-7` is also Preview in the REST API.
- Authoritative model list: Snowflake Service Consumption Table Table 6(b) (Cortex Inference with Prompt Caching), effective July 1, 2026.
