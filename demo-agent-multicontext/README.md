![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--04--02-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Agent Multicontext Demo

> DEMONSTRATION PROJECT - EXPIRES: 2026-04-02
> This demo uses Snowflake features current as of March 2026.
> After expiration, a warning banner will be added to this README and deploy_all.sql.

Demonstrates the Snowflake Agent Run API **"without agent object"** approach for
injecting per-request context -- user identity, station branding, and
authorization-tier-specific tool sets -- via the `instructions.system` field
instead of stuffing context into user messages.

**Pair-programmed by:** SE Community + Cortex Code
**Created:** 2026-03-03 | **Expires:** 2026-04-02 | **Status:** ACTIVE

![Agent Multicontext Demo](assets/demo-screenshot.png)

## Quick Start

**Deploy in Snowsight (no clone needed):**
Copy [`deploy_all.sql`](deploy_all.sql) into a Snowsight worksheet and click **Run All**.

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) demo-agent-multicontext
cd sfe-public/demo-agent-multicontext && cortex
```

## First Time Here?

1. **Deploy Snowflake objects** -- Copy `deploy_all.sql` into Snowsight, click "Run All"

2. **Set environment variables** -- The backend needs your Snowflake account and a Personal Access Token:

   ```bash
   export SNOWFLAKE_ACCOUNT="myorg-myaccount"
   export SNOWFLAKE_PAT="your-personal-access-token"
   ```

   Get a PAT: Snowsight -> Settings -> Authentication -> Personal Access Tokens

3. **Start services** -- `./tools/02_start.sh` (installs deps, starts backend on :3001 and frontend on :3000)

4. **Open** -- Navigate to `http://localhost:3000`

5. **Cleanup** -- Run `teardown_all.sql` in Snowsight, then `./tools/04_stop.sh`

## What This Creates

| Object Type | Name | Purpose |
|---|---|---|
| Schema | `SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT` | Demo schema |
| Warehouse | `SFE_AGENT_MULTICONTEXT_WH` | Demo compute |
| Cortex Search Service | `KB_SEARCH` | Knowledge base search |
| Semantic View | `SV_AGENT_MULTICONTEXT_VIEWERSHIP` | Viewership analytics for Cortex Analyst |
| Tables | `RAW_*`, `MEMBERS`, `STATIONS` | Source data |
| Row Access Policies | `RAP_STATION_*` | Station-scoped data isolation |
| Roles | `TV_VIEWER_ROLE`, `TV_ADMIN_ROLE` | Authorization tiers |

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

The "without agent object" approach trades the Snowsight Agents monitoring
UI (AI & ML > Agents > Monitoring) for per-request flexibility. That UI
requires selecting an agent object, so it is not available when you skip
object creation. Three SQL-based observability paths still work:

| What | Source | Scope |
|------|--------|-------|
| Agent credits and token usage | `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY` | All `agent:run` calls (with and without object) |
| Cortex Analyst request logs | `SNOWFLAKE.LOCAL.CORTEX_ANALYST_REQUESTS()` table function | Scoped to a semantic view |
| Conversation history | Thread REST API (`GET /api/v2/cortex/threads/{id}/messages`) | Per thread |

Threads tie conversations together regardless of which endpoint is used --
the same `thread_id` works with both `/api/v2/cortex/agent:run` and
`/api/v2/databases/{db}/schemas/{schema}/agents/{name}:run`.

See `sql/07_observability_queries.sql` for ready-to-run queries you can
paste into Snowsight after using the demo.

## Operations

| Script | Purpose |
|--------|---------|
| `./tools/02_start.sh` | Install deps, start backend + frontend |
| `./tools/03_status.sh` | Check service health and port status |
| `./tools/04_stop.sh` | Stop all services |
| `sql/07_observability_queries.sql` | Ad-hoc observability queries (run individually in Snowsight) |

- **Backend:** http://localhost:3001 (Express proxy to Snowflake)
- **Frontend:** http://localhost:3000 (Vite dev server, proxies `/api` to backend)
- **Health check:** http://localhost:3001/health

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Backend exits immediately | `SNOWFLAKE_ACCOUNT` or `SNOWFLAKE_PAT` not set. Run `./tools/03_status.sh` to check. |
| Port 3000/3001 already in use | Another process is using the port. Run `lsof -ti :3000` to find it, or `./tools/04_stop.sh` if it's a previous run. |
| "Failed to create thread" in chat | Verify PAT is valid and not expired. Check `http://localhost:3001/health` for account connectivity. |
| Agent returns empty responses | Cortex Search service needs time to index after deploy. Wait a few minutes and retry. |
| Analyst tool errors | Verify `SFE_AGENT_MULTICONTEXT_WH` is running and the semantic view exists in `SEMANTIC_MODELS`. |

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skills (Cursor + Claude Code)
- **Cortex Code in Snowsight** -- Open this project in a Workspace for AI-assisted development
- **Cursor** -- Open locally with Cursor for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)

## Estimated Demo Costs

| Component | Size | Est. Credits/Hour |
|---|---|---|
| Warehouse (SFE_AGENT_MULTICONTEXT_WH) | X-SMALL | 1 |
| Cortex Search Service | Serverless | ~0.1 |
| Cortex Agent calls | Per-query | ~0.01/query |
| Cortex Analyst calls | Per-query | ~0.01/query |

**Total estimated cost:** <2 credits for full deployment + 1 hour of exploration.

## Cleanup

1. Run `teardown_all.sql` in Snowsight
2. Stop local services: `./tools/04_stop.sh`

## References

- [Cortex Agents Run API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run) -- `agent:run` with and without agent object
- [Cortex Agents REST API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-rest-api) -- CRUD operations for agent objects
- [Monitor Cortex Agent Requests](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-monitor) -- Observability and tracing (requires agent object)
- [CORTEX_AGENT_USAGE_HISTORY](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_agent_usage_history) -- Usage view for all `agent:run` calls
- [Cortex Analyst Administrator Monitoring](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/admin-observability) -- Analyst request logs and SQL queries
- [Setting Execution Context](https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/setting-context) -- X-Snowflake-Role and X-Snowflake-Warehouse headers

## License

Apache 2.0 -- See individual file headers for details.
