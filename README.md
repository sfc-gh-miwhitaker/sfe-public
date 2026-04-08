![Projects](https://img.shields.io/badge/Projects-20-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Solutions Engineering -- Public Examples

Snowflake demos, tools, and guides -- each self-contained with deployment scripts and teardown. Every project includes an `AGENTS.md` file that works with AI coding assistants ([Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Cursor](https://www.cursor.com/)) to guide you through deployment and usage.

> **No support is provided.** All code is shared for reference and learning. Review, test, and modify thoroughly before any production use.

## Brand New to All of This?

Never used GitHub or any of these tools before? Start here:

1. **Get the code** -- Click the green **Code** button on any project page and select **Download ZIP**, or use the one-liner below
2. **Get an AI assistant** -- Install [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), or [Cursor](https://www.cursor.com/)
3. **Open a project** -- Navigate to any demo folder below and tell the AI: *"Help me get started with this project"*

The AI reads the project's `AGENTS.md`, understands the deployment steps, and walks you through everything.

---

## Projects

### Demos

Full demonstration projects with `deploy_all.sql` and `teardown_all.sql`.

| Directory | Description | Features |
|---|---|---|
| [demo-cortex-teams-agent](demo-cortex-teams-agent/) | Snowflake Cortex Agents for Microsoft Teams & M365 Copilot | Cortex Agents, AI_COMPLETE, Cortex Guard |
| [glaze-and-classify](https://github.com/sfc-gh-miwhitaker/glaze-and-classify) | Multi-method product classification showdown (SQL, Cortex AI, SPCS Vision) | AI_COMPLETE, SPCS, Semantic Views, Intelligence Agents |
| [demo-cortex-financial-agents](demo-cortex-financial-agents/) | Specialty finance portfolio risk agent combining structured analytics with document RAG | Cortex Agents, Cortex Search, Semantic Views, Cortex Analyst |
| [demo-music-label-marketing-analytics](demo-music-label-marketing-analytics/) | Music label marketing analytics with AI enrichment, spreadsheet-style budget entry, and Intelligence agent | Dynamic Tables, AI_CLASSIFY, AI_EXTRACT, Semantic Views, Streamlit, Intelligence Agents |
| [demo-gaming-player-analytics](demo-gaming-player-analytics/) | Player behavior analytics with AI cohort segmentation, churn risk scoring, feedback analysis, and Intelligence agent | Dynamic Tables, AI_CLASSIFY, AI_EXTRACT, Semantic Views, Streamlit, Intelligence Agents |

### Deployable Tools

Focused utilities with `deploy_all.sql` (or `deploy.sql`) and matching teardown.

| Directory | Description | Features |
|---|---|---|
| [tool-ai-spend-controls](tool-ai-spend-controls/) | Control Cortex AI Function spend — monitoring, alerts, per-user limits, runaway detection | Notebooks, Streamlit, ACCOUNT_USAGE, Alerts, Tasks |
| [tool-code-spend-controls](tool-code-spend-controls/) | Control Cortex Code spend — budgets, per-user limits, RBAC, scenario runbooks | Notebooks, Worksheets, ACCOUNT_USAGE, Budgets |
| [tool-dr-cost-agent](tool-dr-cost-agent/) | DR replication cost estimation agent with hybrid table awareness | Snowflake Intelligence, Semantic Views, ACCOUNT_USAGE |
| [tool-cortex-semantic-enhancer](tool-cortex-semantic-enhancer/) | AI-enhanced semantic view descriptions using Cortex | AI_COMPLETE, Semantic Views |

### Guides and References

Documentation, patterns, and examples (no deploy/teardown).

| Directory | Description | Features |
|---|---|---|
| [guide-csv-import](guide-csv-import/) | Load CSV files into Snowflake: one-time setup, repeatable imports, and automation | Stages, COPY INTO, File Formats |
| [guide-agent-skills](guide-agent-skills/) | Agent skills as resource management: context budget mental model | Skills, Context Management |
| [guide-cortex-anthropic-redirect](guide-cortex-anthropic-redirect/) | Redirect Anthropic SDK calls to Snowflake Cortex with 3 code changes | Cortex REST API, Messages API, PAT Auth |
| [guide-ai-tool-rollout](guide-ai-tool-rollout/) | Roll out AI coding tools enterprise-wide: MDM, Snowflake standards, red-team, distribution | managed-settings.json, MDM, Dual-Surface |
| [guide-agent-hardening](guide-agent-hardening/) | Harden Cortex Agents for production: monitoring, RBAC, guardrails, cost controls, config diff | Cortex Guard, CORTEX_AGENT_USAGE_HISTORY, Row Access Policies, DESC AGENT |
| [guide-mcp-auth](guide-mcp-auth/) | MCP server authentication walkthrough: PAT, OAuth + PKCE, RBAC, multi-tenant, enterprise IdP | Snowflake MCP, OAuth, PAT, RBAC |
| [guide-data-quality-governance](guide-data-quality-governance/) | Data quality governance: DMFs, tagging, masking, anomaly detection | Data Metric Functions, Tags, Masking Policies |
| [guide-semi-structured-pipeline](guide-semi-structured-pipeline/) | Bronze-to-gold pipeline architecture for semi-structured data with Dynamic Tables | Dynamic Tables, TRY_CAST, FLATTEN, INFER_SCHEMA, OpenFlow, DMFs |
| [guide-external-access-playbook](guide-external-access-playbook/) | External access patterns: network rules, EAI, secrets, OAuth | External Access Integration, Network Rules, Secrets |
| [guide-powerbi-live-query](guide-powerbi-live-query/) | Power BI DirectQuery at scale: interactive tables, hybrid tables, and optimization patterns | Interactive Tables, Interactive Warehouses, Hybrid Tables, Power BI SSO |
| [guide-powerbi-onelake-iceberg](guide-powerbi-onelake-iceberg/) | Power BI + Snowflake via OneLake and Iceberg: bi-directional access and Direct Lake mode | Iceberg Tables, OneLake, Catalog-Linked Databases, External Volumes |
| [guide-query-tuning](guide-query-tuning/) | Tune queries to reduce warehouse cost: pruning, clustering, and search optimization before resizing | Warehouse Optimization, Clustering, Search Optimization, Pruning |
| [guide-coco-connections](guide-coco-connections/) | Multi-connection setup for Cortex Code CLI: config.toml, launch patterns, per-project AGENTS.md, environment isolation | Cortex Code CLI, connections.toml, AGENTS.md, Partner SE |


## Learning Journeys

Not sure where to start? Each journey connects 3-5 projects into a story: understand the use case, deploy an example, then learn the governance patterns.

| Journey | Story | Path | Start Here |
|---|---|---|---|
| **Agents** | Learn the Cortex Agent API with per-request context injection, then deploy to Teams, harden for production, and connect via MCP | demo-cortex-teams-agent → guide-agent-hardening → guide-mcp-auth | [demo-cortex-teams-agent](demo-cortex-teams-agent/) |
| **AI Governance** | Roll out AI coding tools across your organization | guide-agent-skills → guide-ai-tool-rollout | [guide-agent-skills](guide-agent-skills/) |
| **FinOps** | Understand Cortex billing, control AI and Code spend, tune warehouse queries | guide-cortex-anthropic-redirect → tool-ai-spend-controls → tool-code-spend-controls → guide-query-tuning | [guide-cortex-anthropic-redirect](guide-cortex-anthropic-redirect/) |
| **Data Quality** | Load data, build a pipeline, add quality gates and governance | guide-csv-import → guide-semi-structured-pipeline → guide-data-quality-governance | [guide-csv-import](guide-csv-import/) |
| **External Access** | Call external APIs from Snowflake, manage secrets, harden for production | guide-external-access-playbook | [guide-external-access-playbook](guide-external-access-playbook/) |
| **Search & RAG** | Build a Cortex Search service, then integrate it into a financial agent | demo-cortex-financial-agents | [demo-cortex-financial-agents](demo-cortex-financial-agents/) |
| **BI Integration** | Connect Power BI via DirectQuery and OneLake/Iceberg | guide-powerbi-live-query → guide-powerbi-onelake-iceberg | [guide-powerbi-live-query](guide-powerbi-live-query/) |
---

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

### Deploy in Snowsight (no clone needed)

Most demos and tools deploy entirely inside Snowflake. The deploy script creates a Git Repository object, fetches from GitHub, and runs everything server-side.

1. Browse the project on [GitHub](https://github.com/sfc-gh-miwhitaker/sfe-public)
2. Open its `deploy_all.sql` (or `deploy.sql`) and copy into a Snowsight worksheet
3. Click **Run All**
4. See the project README for usage instructions

### Guides

Open the guide directory and follow the README.

## Shared Infrastructure

Every deploy script is fully self-contained. Each one creates the shared infrastructure it needs inline (using `IF NOT EXISTS`), so no separate setup step is ever required:

| Resource | Name | Purpose |
|---|---|---|
| Database | `SNOWFLAKE_EXAMPLE` | Shared demo database |
| API Integration | `SFE_GIT_API_INTEGRATION` | GitHub access for Git Repository stages |
| Git Repository | `SFE_DEMOS_REPO` | Shared monorepo Git stage (in `GIT_REPOS` schema) |

Each project creates its own schema and warehouse within `SNOWFLAKE_EXAMPLE`.

## License

Apache License 2.0. See [LICENSE](LICENSE) and each project directory.
