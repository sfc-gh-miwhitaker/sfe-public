# Agent Multicontext Demo

![Expires](https://img.shields.io/badge/Expires-2026--04--02-orange)

> DEMONSTRATION PROJECT - EXPIRES: 2026-04-02
> This demo uses Snowflake features current as of March 2026.
> After expiration, a warning banner will be added to this README and deploy_all.sql.

Demonstrates the Snowflake Agent Run API **"without agent object"** approach for
injecting per-request context -- user identity, station branding, and
authorization-tier-specific tool sets -- via the `instructions.system` field
instead of stuffing context into user messages.

**Pair-programmed by:** SE Community + Cortex Code
**Created:** 2026-03-03 | **Expires:** 2026-04-02 | **Status:** ACTIVE

## First Time Here?

1. **Deploy** -- Copy `deploy_all.sql` into Snowsight, click "Run All"
2. **Start backend** -- `cd backend && npm install && npm start`
3. **Start frontend** -- `cd frontend && npm install && npm run dev`
4. **Open** -- Navigate to `http://localhost:3000`
5. **Cleanup** -- Run `teardown_all.sql` when done

## What This Demo Shows

### The Problem

When building a customer-facing agent on Snowflake, you need to pass
per-user context (user ID, station affiliation, authorization level) to
the agent. The "with agent object" API endpoint
(`POST /api/v2/databases/{db}/schemas/{schema}/agents/{name}:run`) does
not allow overriding `instructions` per request.

The common workaround -- prepending "Do not repeat, but remember: my user id
is xxxxx" to every message -- is fragile, pollutes the conversation history,
and mixes data with user intent.

### The Solution

Use the **"without agent object"** endpoint (`POST /api/v2/cortex/agent:run`).
This endpoint accepts the full agent specification inline per request, including:

- `instructions.system` -- User identity, station branding, authorization context
- `instructions.response` -- Response style tailored to auth tier
- `instructions.orchestration` -- Tool selection guidance per tier
- `tools` + `tool_resources` -- Different tool sets per authorization level
- `X-Snowflake-Role` header -- Snowflake role for RBAC enforcement

### Three User Tiers

| Tier | User Context | Tools | Snowflake Role |
|------|-------------|-------|----------------|
| **Anonymous** | No user ID | Cortex Search (KB) only | _(default)_ |
| **Basic Member** | User ID + name in system prompt | Search + Analyst (viewership) | `TV_VIEWER_ROLE` |
| **Station Admin** | User ID + admin flag in system prompt | Search + full Analyst (metrics, members) | `TV_ADMIN_ROLE` |

### Station Branding

The agent's identity changes based on which station the user arrives from.
The system prompt begins with "You are the WETA Support Agent" or
"You are the KQED Support Agent" depending on the referring domain.
No separate agent objects needed per station.

## Architecture

```
React Frontend          Node.js Backend            Snowflake
┌─────────────┐        ┌──────────────────┐       ┌──────────────────┐
│ UserPicker   │──┐     │ Context Builder  │       │ agent:run API    │
│ StationPicker│  ├────▶│ builds system    │──────▶│ (without object) │
│ AgentChat    │  │     │ prompt + tools   │       │                  │
│ ApiInspector │──┘     │ per request      │       │ Cortex Search    │
└─────────────┘        └──────────────────┘       │ Cortex Analyst   │
                                                   │ Row Access Policy│
                                                   └──────────────────┘
```

## API Inspector

The sidebar includes a live JSON inspector that shows the exact payload
being sent to the Snowflake Agent API. Toggle between tabs to see:

- **instructions** -- How `system`, `response`, and `orchestration` change
- **tools** -- Which tools are available at each auth tier
- **full payload** -- The complete request body

## Observability

Agent monitoring works with the "without agent object" approach. All
conversations and traces are available in the Snowflake UI under
AI & ML > Agents > Monitoring. Logs are stored in
`SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS`. Threads tie conversations
together regardless of which endpoint is used.

## Environment Variables

### Backend

```bash
export SNOWFLAKE_ACCOUNT="myorg-myaccount"
export SNOWFLAKE_PAT="your-personal-access-token"
```

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **Cortex Code in Snowsight** -- Open this project in a Workspace for AI-assisted development
- **Cursor** -- Open locally with Cursor for AI-pair coding

## References

- [Cortex Agents Run API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run) -- `agent:run` with and without agent object
- [Cortex Agents REST API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-rest-api) -- CRUD operations for agent objects
- [Monitor Cortex Agent Requests](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-monitor) -- Observability and tracing
- [Setting Execution Context](https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/setting-context) -- X-Snowflake-Role and X-Snowflake-Warehouse headers
