![Projects](https://img.shields.io/badge/Projects-10-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Solutions Engineering -- Public Examples

Snowflake guides for connecting AI coding assistants to Snowflake. Every project includes an `AGENTS.md` file that works with AI coding assistants ([Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Cursor](https://www.cursor.com/)) to guide you through deployment and usage.

> **No support is provided.** All code is shared for reference and learning. Review, test, and modify thoroughly before any production use.

## Projects

### Guides and References

| Directory | Description | Features |
|---|---|---|
| [guide-powerbi-oauth](guide-powerbi-oauth/) | Configure Power BI to connect to Snowflake using OAuth SSO (Microsoft Entra ID): security integration setup, DirectQuery vs Import mode, user provisioning (LOGIN_NAME = UPN), per-viewer identity for row-level security, B2B guests, Azure Government, network policies, and a full troubleshooting error table | Power BI, OAuth, DirectQuery, External OAuth, Entra ID, Azure AD, security integration, row-level security |
| [guide-horizon-context-catalog](guide-horizon-context-catalog/) | The catalog pivot explained: Select Star acquisition → Horizon Context (Collect/Enrich/Activate, Wave 1 connectors, OpenLineage, OSI) → Cortex Sense (runtime context activation, ~86% benchmark). Covers the dual security boundary question for customers who used semantic views + RBAC as two checkpoints, what changes with Sense's single-role private preview, and practical guidance on when to keep explicit scoping vs enable Sense. Validated claims only; availability table; common objections | Horizon Context, Cortex Sense, Select Star, metadata connectors, semantic view security, dual security boundary, catalog pivot |
| [guide-agent-to-agent-orchestration](guide-agent-to-agent-orchestration/) | Which mechanism to use when one Cortex Agent calls another: same-account wrapper + `DATA_AGENT_RUN`, inter-app agents (RCR + `GRANT CALLER`), MCP as the interop fabric, CoWork. Honest about what isn't native (no Google A2A). Includes a working same-account agent→agent spec and the caller-grants-don't-chain gotcha | Cortex Agents, DATA_AGENT_RUN, inter-app agents, RCR, MCP, CoWork |
| [guide-cortex-agent-versioning](guide-cortex-agent-versioning/) | How to version Cortex Agents with GitHub: the commit-based model (`LIVE` → `VERSION$N` → alias → default), iterate-in-Snowflake vs Git-driven compared, native Git import (`ADD VERSION FROM @repo/...`), promote/rollback, and example CI/CD. Ships a runnable ORDERS agent and the COMMIT-destroys-LIVE gotcha | Cortex Agents, agent versioning, GitHub, Git integration, CI/CD, promote/rollback |
| [guide-cortex-sense](guide-cortex-sense/) | Deep-dive SE guide on Cortex Sense (private preview mid-July 2026): the three-layer stack (Horizon Catalog → Horizon Context → Cortex Sense), all Summit 2026 announcements (connectors, Autopilot, Semantic Studio, Advanced Semantics, OSI), the self-correcting evaluation loop, benchmark positioning (~24% → ~86%), cost model, and brief Databricks Genie Ontology comparison | Cortex Sense, Horizon Context, Horizon Catalog, Semantic View Autopilot, context layer, agent accuracy |
| [guide-claude-code-cortex-redirect](guide-claude-code-cortex-redirect/) | How to redirect `claude` CLI and Anthropic/OpenAI SDK inference to Snowflake Cortex instead of Anthropic directly — so all inference runs inside the Snowflake perimeter, governed by RBAC and billed to Snowflake. Covers `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` setup, per-user and org-wide enforcement, SDK patterns (Python + Node, Messages API + Chat Completions), verification via `CORTEX_REST_API_USAGE_HISTORY`, and auth gotchas | Cortex REST API, ANTHROPIC_BASE_URL, SDK redirect, Claude Code, inference governance |
| [guide-connecting-claude-snowflake](guide-connecting-claude-snowflake/) | Post-Summit-26 guide to putting Claude in front of Snowflake: context over connection. Why raw text-to-SQL is ~24% accurate, how Horizon Context + Cortex Sense reach ~86%, CoWork/CoCo surfaces, Natoma governed MCP gateway; legacy OAuth/Entra MCP demoted | CoWork, CoCo, Cortex Sense, Horizon Context, Natoma, governed MCP |
| [guide-snowflake-cost-visibility](guide-snowflake-cost-visibility/) | Foundational cost governance: Budget object (predictive spend alerts), METERING_DAILY_HISTORY attribution queries, Resource Monitors (warehouse guardrails), and AI_FUNCTIONS_USER RBAC for new BU governance. Companion to guide-cortex-ai-cost-controls | Budget object, ACCOUNT_USAGE, resource monitors, AI_FUNCTIONS_USER, RBAC, cost visibility |
| [guide-vscode-copilot-cortex](guide-vscode-copilot-cortex/) | Connect VS Code GitHub Copilot to Snowflake Cortex: managed MCP for Copilot Chat, subagent skill for Copilot CLI, and the CoCo CLI (formerly Cortex Code) in the integrated terminal. Post-Summit-26, with the shared semantic-view accuracy foundation | Snowflake MCP, OAuth, PAT, subagent-cortex-code, CoCo CLI |

### Demos

| Directory | Description | Features |
|---|---|---|
| [demo-cortex-ai-cost-controls](demo-cortex-ai-cost-controls/) | Deployable Streamlit-in-Snowflake dashboard companion to guide-cortex-ai-cost-controls. Reads LIVE `SNOWFLAKE.ACCOUNT_USAGE` to show AI spend, attribute by cost center, manage per-user AI Function limits (simulate-only), catch runaway queries, and flag anomalies across five pages | Streamlit-in-Snowflake, Cortex AI, ACCOUNT_USAGE, simulate-only enforcement, runaway protection, budgets |
| [demo-media-campaign-analytics](demo-media-campaign-analytics/) | Cortex Agent demo for paid media analytics. One agent answers both quantitative questions (ROAS, CTR, budget pacing via semantic view) and qualitative questions (campaign briefs, creative copy, channel strategy via Cortex Search). 5-min deploy, zero external tools | Cortex Agent, Semantic View, Cortex Search, Snowflake Intelligence, media analytics, document search |

## First-Time Setup

Run once on your machine. Configures pre-commit to run automatically on every commit in **every git repository** that has a `.pre-commit-config.yaml` — no per-repo setup required after this.

```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/setup-dev.sh)
```

What it does: installs `pre-commit` (if missing) and sets `git config --global core.hooksPath` to a dispatcher that runs pre-commit in any repo with a config file. Idempotent — safe to re-run.

To add this protection to a repo that does not yet have a config, copy the standard template:
```bash
cp shared/pre-commit-config-template.yaml /path/to/repo/.pre-commit-config.yaml
cd /path/to/repo && detect-secrets scan > .secrets.baseline
```

## Quick Start

### Develop with AI Assistance

```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) <project-name>
cd sfe-public/<project-name>
```

Then open the project with your AI assistant of choice:
- **Cortex Code:** `cortex`
- **Claude Code:** `claude`
- **Cursor:** Open the folder in Cursor

Tell the AI: *"Help me get started with this project"*

Every project includes an `AGENTS.md` that any Claude-compatible tool reads automatically.

### Guides

Open the guide directory and follow the README.

## License

Apache License 2.0. See [LICENSE](LICENSE) and each project directory.
