# Agent-to-Agent Orchestration on Snowflake — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Documentation-only guide (no deploy scripts, no Snowflake objects to create). Thesis: **Snowflake has no proprietary agent-to-agent bus — it makes the child agent look like a tool** (a SQL wrapper procedure or an MCP server) inside the parent agent's normal plan→act loop.

Two self-contained docs:

- `README.md` — Router + positioning. Decision tree, the 5-row "Need → Use" table, the five layers (single-agent loop → same-account wrapper → inter-app → MCP fabric → CoWork), the honest-gaps table, the customer-framing section.
- `same-account-agent-to-agent.md` — Working illustrative spec for the GA same-account case: child agent → `EXECUTE AS OWNER` wrapper proc → `DATA_AGENT_RUN` → parent agent with a `generic`/`procedure` tool. Gotchas table.

## Verified facts (checked against docs 2026-06-30 — re-verify, this area moves fast)

- `DATA_AGENT_RUN('db.schema.agent', body [, create_thread])` runs a **named** agent. `AGENT_RUN(body [, create_thread])` runs an **objectless** agent. Both GA, both non-streaming wrappers around the Cortex Agents Run API. For agent→agent, use `DATA_AGENT_RUN`.
- Inter-app agents = **Preview (Open)**, all accounts. RCR enforced for Native App Cortex Agents on **June 5, 2026** (now in effect; pre-cutoff versions grandfathered).
- **Caller grants do NOT chain** through an owner's-rights wrapper proc — each RCR agent's grant requirement is independent (verbatim in the inter-app doc). This is the headline gotcha.
- MCP: `CREATE MCP SERVER` (managed, GA) tool types = `CORTEX_SEARCH_SERVICE_QUERY`, `CORTEX_ANALYST_MESSAGE`, `SYSTEM_EXECUTE_SQL`, `CORTEX_AGENT_RUN`, `GENERIC`. `CREATE CUSTOM MCP SERVER` = SPCS-hosted. **Max recursion depth 10**, max 50 tools per server.
- App-created **managed** MCP servers are restricted to app-owned tools (no `SYSTEM_EXECUTE_SQL`).
- **No native Google A2A endpoint** — bridge only via custom MCP / A2A Agent Card server.
- The "`AGENT_RUN()` shows intent but never executes tools" claim is a **community blog report, NOT documented** — frame as "validate in POC," never assert.

## Conventions

- **Audience is new to Snowflake** — no jargon without definition. Every Snowflake/AI term gets defined once in the README glossary ("New to Snowflake? Read these words once"); the hands-on doc links back to it. New terms → add a glossary row, don't just use them inline.
- Placeholder syntax: `<UPPERCASE_WITH_UNDERSCORES>` or `MY_DB.MY_SCHEMA.*` for values the reader replaces.
- Label maturity honestly per layer (GA vs Preview). The created-date verification note in the README header is load-bearing — keep it.
- Each doc self-contained; cross-links use relative markdown links.
- Agent specs use `orchestration: auto`, never a pinned model name (region availability).

## Key Commands

This is a guide — there is nothing to deploy. The only "commands" are the illustrative SQL snippets in `same-account-agent-to-agent.md` (`CREATE AGENT`, `CREATE PROCEDURE ... EXECUTE AS OWNER`, `DATA_AGENT_RUN`).
