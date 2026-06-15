# Agent Governance Playbook

Operational patterns for running Cortex Agents in production: monitoring, access control, content safety, cost controls, and audit trails. Extracts proven patterns from demos and tools in this repository.

## Project Structure

- `README.md` -- Complete guide (6 parts + production checklist + agent config diff appendix)
- `scripts/extract_agent_spec.sql` -- Interactive SQL for agent spec extraction (Snowsight/SnowSQL)
- `scripts/extract_agent_spec.py` -- Programmatic Python alternative (no session state needed)

## Content Principles

- Extract patterns already proven in demos (not theoretical)
- SQL examples sourced from tool-ai-spend-controls and Snowflake documentation
- Six-part progression: content safety, access control, authentication, network security, monitoring, cost controls
- Every recommendation maps to a working example in a related project

## When Helping with This Project

- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects to create
- Most SQL is embedded in README.md; standalone utility scripts live in `scripts/`
- Cortex Guard uses boolean `true` (not the old object syntax)
- Network policies for agents are supported as of March 2026, with caveats
- CORTEX_AGENT_USAGE_HISTORY has up to 3-hour latency
- TOKENS_GRANULAR is an ARRAY -- flatten with `LATERAL FLATTEN` to extract per-call token counts
- Per-user budgets come from tool-ai-spend-controls governance module

## Related Projects

- [`tool-ai-spend-controls`](../tool-ai-spend-controls/) -- Cost governance with budgets, alerts, runaway detection
- [`guide-agent-multi-tenant`](../guide-agent-multi-tenant/) -- Multi-tenant agent patterns: session variables, isolation gotchas, API reference
- [`guide-mcp-auth`](../guide-mcp-auth/) -- MCP server auth for all AI clients
- [`guide-connecting-claude-snowflake`](../guide-connecting-claude-snowflake/) -- Claude-specific auth paths
- [`guide-ai-tool-rollout`](../guide-ai-tool-rollout/) -- AI coding tool governance workshop
