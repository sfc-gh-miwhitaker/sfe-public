---
name: demo-agent-multicontext
description: "Per-request context injection using Snowflake Agent Run API without agent object. Triggers: multicontext agent, per-request context, agent:run inline, authorization tiers, station branding, tool gating, anonymous basic admin tiers."
---

# Multicontext Agent Patterns

## Purpose

Per-request context injection using the Snowflake Agent Run API "without agent object" endpoint. This skill covers the payload construction pattern, the three-tier authorization model, and how to extend both.

## When to Use

- Adding a new authorization tier or modifying tool availability
- Changing system prompt logic for a tier
- Adding a new Cortex tool (Search service, Analyst semantic view)
- Debugging payload construction or SSE streaming
- Understanding why the backend is the authoritative payload source

## Architecture

The "without agent object" endpoint (`POST /api/v2/cortex/agent:run`) accepts the full agent specification inline per request. Every field -- `instructions`, `tools`, `tool_resources`, and the `X-Snowflake-Role` header -- can change per request without creating or modifying an agent object in Snowflake.

```
User picks station + tier
        |
        v
  React Frontend  ──POST /api/agent/run──>  Node.js Backend
  (preview only)                             (authoritative payload builder)
                                                    |
                                                    v
                                             POST /api/v2/cortex/agent:run
                                             + X-Snowflake-Role header
                                                    |
                                                    v
                                              Snowflake Cortex
                                              (Search + Analyst)
```

## Key Files

| File | Role |
|------|------|
| `backend/server.js` | **Authoritative** payload builder. `buildAgentPayload()` constructs `instructions`, `tools`, `tool_resources`, and selects the Snowflake role. |
| `frontend/src/utils/buildAgentPayload.ts` | **Preview mirror** of the backend logic for the API Inspector panel. Must stay in sync but is never sent to Snowflake. |
| `frontend/src/hooks/useAgentChat.ts` | SSE streaming client. Handles thread creation, `response.text.delta` events, and `metadata` events for parent message tracking. |

## Three-Tier Authorization Model

| Tier | `userType` | Tools Available | Snowflake Role | System Prompt Includes |
|------|-----------|-----------------|----------------|----------------------|
| Anonymous | `anonymous` | Cortex Search (KB) only | _(default)_ | "NOT logged in" |
| Basic Member | `low` | Search + Analyst (viewership) | `TV_VIEWER_ROLE` | User name, member ID, tier |
| Station Admin | `full` | Search + full Analyst | `TV_ADMIN_ROLE` | User name, member ID, admin flag |

## Extension Playbook: Adding a New Tool

1. Add the tool spec and resource in `buildTools()` in `backend/server.js`
2. Gate it behind the appropriate `userType` check
3. Update `buildOrchestrationInstructions()` to guide the agent on when to use it
4. Mirror the change in `frontend/src/utils/buildAgentPayload.ts` for the API Inspector
5. If the tool needs a new Snowflake object, add it to both `deploy_all.sql` and `teardown_all.sql`

## Extension Playbook: Adding a New Tier

1. Add the tier to the `if/else` chain in `buildSystemInstructions()`, `buildResponseInstructions()`, `buildOrchestrationInstructions()`, and `buildTools()`
2. Create the corresponding Snowflake role in `sql/06_roles_and_grants.sql` and `deploy_all.sql`
3. Add the role to teardown
4. Mirror in `frontend/src/utils/buildAgentPayload.ts`

## Station Branding

The system prompt begins with the station identity: "You are the WETA Support Agent (WETA)." Station selection changes the prompt without separate agent objects. The station registry lives in `backend/server.js` (`STATIONS` constant) and is mirrored in the frontend.

## Payload Standards

- `models.orchestration` is always `'auto'` (never pin a model)
- `orchestration_budget` sets `seconds: 30` and `tokens: 4096`
- Thread management: backend creates threads via `POST /api/v2/cortex/threads`, tracks `parent_message_id` from SSE `metadata` events

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT` |
| Warehouse | `SFE_AGENT_MULTICONTEXT_WH` |
| Cortex Search | `SUPPORT_KB_SEARCH` |
| Semantic View | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AGENT_MULTICONTEXT_VIEWERSHIP` |

## Gotchas

- Backend is authoritative -- frontend `buildAgentPayload.ts` is for preview only
- `X-Snowflake-Role` header controls RBAC, not the payload
- Thread IDs must be created via API before referencing in agent:run calls
- SSE `metadata` events carry `parent_message_id` needed for multi-turn threading
