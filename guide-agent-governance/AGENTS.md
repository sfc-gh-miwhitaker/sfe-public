# Agent Governance Playbook

Operational patterns for running Cortex Agents in production: monitoring, access control, content safety, cost controls, and audit trails. Extracts proven patterns from demos and tools in this repository.

## Project Structure

- `README.md` -- Complete guide (6 parts + production checklist + agent config diff appendix)
- `scripts/extract_agent_spec.sql` -- Interactive SQL for agent spec extraction (Snowsight/SnowSQL)
- `scripts/extract_agent_spec.py` -- Programmatic Python alternative (no session state needed)

## Content Principles

- Extract patterns already proven in demos (not theoretical)
- SQL examples sourced from demo-agent-multicontext, demo-cortex-teams-agent, tool-cortex-cost-intelligence
- Six-part progression: content safety, access control, authentication, network security, monitoring, cost controls
- Every recommendation maps to a working example in a related project

## When Helping with This Project

- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects to create
- All SQL is embedded in README.md (no separate .sql files)
- Cortex Guard uses boolean `true` (not the old object syntax)
- Network policies for agents are supported as of March 2026, with caveats
- CORTEX_AGENT_USAGE_HISTORY has up to 3-hour latency
- TOKENS_GRANULAR is an OBJECT, not an array -- access via `:"input"::NUMBER`
- Per-user budgets come from tool-cortex-cost-intelligence governance module

## Related Projects

- [`demo-campaign-engine`](../demo-campaign-engine/) -- Build an agent from scratch with GUIDED_BUILD workshop
- [`demo-cortex-teams-agent`](../demo-cortex-teams-agent/) -- Agent with Cortex Guard and security integration
- [`demo-agent-multicontext`](../demo-agent-multicontext/) -- Row Access Policies and observability patterns
- [`tool-cortex-cost-intelligence`](../tool-cortex-cost-intelligence/) -- Cost governance with budgets, alerts, runaway detection
- [`guide-api-agent-context`](../guide-api-agent-context/) -- Agent Run API with three auth methods
- [`guide-agent-multi-tenant`](../guide-agent-multi-tenant/) -- Multi-tenant architecture with Azure AD OAuth + RAPs
