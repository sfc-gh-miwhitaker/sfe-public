![Projects](https://img.shields.io/badge/Projects-36-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Solutions Engineering -- Public Examples

Snowflake demos, tools, and guides -- each self-contained with deployment scripts, teardown, and AI-assisted development via [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli). Clone a project, run `cortex`, and let the AI guide you through deployment and usage.

> **No support is provided.** All code is shared for reference and learning. Review, test, and modify thoroughly before any production use.

## Brand New to All of This?

Never used GitHub, Cortex Code, or any of these tools before? Start here:

1. **Get the code** -- [How to download from GitHub](guide-coco-setup/#part-0-getting-the-code) (no experience required)
2. **Get Cortex Code** -- [Install the AI assistant](guide-coco-setup/#part-1-the-learning-path) that will help you with everything else
3. **Open a project** -- Navigate to any demo folder below, then tell Cortex Code: *"Help me get started with this project"*

The AI will guide you through deployment and usage. You don't need to understand all the technical details upfront.

---

## Projects

### Demos

Full demonstration projects with `deploy_all.sql` and `teardown_all.sql`.

| Directory | Description | Features |
|---|---|---|
| [demo-agent-multicontext](demo-agent-multicontext/) | Per-request context injection via the Agent Run API (TV network multi-tenant) | Cortex Agents, Agent Run API, Semantic Views, Row Access Policies |
| [demo-cortex-teams-agent](demo-cortex-teams-agent/) | Snowflake Cortex Agents for Microsoft Teams & M365 Copilot | Cortex Agents, AI_COMPLETE, Cortex Guard |
| [demo-cortex-openai-enrichment](demo-cortex-openai-enrichment/) | AI-First Data Engineering: OpenAI + Snowflake Cortex | External Access, AI_COMPLETE, Dynamic Tables, VARIANT |
| [glaze-and-classify](https://github.com/sfc-gh-miwhitaker/glaze-and-classify) | Multi-method product classification showdown (SQL, Cortex AI, SPCS Vision) | AI_COMPLETE, SPCS, Semantic Views, Intelligence Agents |
| [demo-dataquality-metrics](demo-dataquality-metrics/) | Data Quality Metrics & Reporting with DMFs and Streamlit | Data Metric Functions, Dynamic Tables, Streamlit |
| [demo-api-quickbooks-medallion](demo-api-quickbooks-medallion/) | QuickBooks API medallion architecture with Cortex AI enrichment and DQ monitoring | External Access, Medallion Architecture, AI_COMPLETE, DMFs |
| [demo-campaign-engine](demo-campaign-engine/) | Casino campaign recommendation engine with ML targeting and vector lookalike matching | Dynamic Tables, ML CLASSIFICATION, VECTOR, Cortex Agents |
| [demo-cortex-financial-agents](demo-cortex-financial-agents/) | Specialty finance portfolio risk agent combining structured analytics with document RAG | Cortex Agents, Cortex Search, Semantic Views, Cortex Analyst |
| [demo-coco-governance-github](demo-coco-governance-github/) | GitHub-powered AGENTS.md and skills governance across Cortex Code surfaces | Cortex Code, GitHub, AGENTS.md, Intune |
| [demo-music-label-marketing-analytics](demo-music-label-marketing-analytics/) | Music label marketing analytics with AI enrichment, spreadsheet-style budget entry, and Intelligence agent | Dynamic Tables, AI_CLASSIFY, AI_EXTRACT, Semantic Views, Streamlit, Intelligence Agents |
| [demo-cortex-product-classification](demo-cortex-product-classification/) | Pointer to [glaze-and-classify](https://github.com/sfc-gh-miwhitaker/glaze-and-classify) (multi-method product classification) | AI_COMPLETE, SPCS, Semantic Views |

### Deployable Tools

Focused utilities with `deploy_all.sql` (or `deploy.sql`) and matching teardown.

| Directory | Description | Features |
|---|---|---|
| [tool-cortex-rest-api-cost](tool-cortex-rest-api-cost/) | Cortex REST API cost dashboard -- tracks direct API calls and calculates dollar cost from token pricing | CORTEX_REST_API_USAGE_HISTORY, Streamlit in Snowflake |
| [tool-cortex-cost-intelligence](tool-cortex-cost-intelligence/) | Cortex cost governance with semantic views and Cortex Agents | ACCOUNT_USAGE, Semantic Views, Cortex Agents, Streamlit |
| [tool-dr-cost-agent](tool-dr-cost-agent/) | DR replication cost estimation agent with hybrid table awareness | Snowflake Intelligence, Semantic Views, ACCOUNT_USAGE |
| [tool-cortex-semantic-enhancer](tool-cortex-semantic-enhancer/) | AI-enhanced semantic view descriptions using Cortex | AI_COMPLETE, Semantic Views |
| [tool-streamlit-contact-form](tool-streamlit-contact-form/) | Streamlit form that writes submissions to a Snowflake table | Streamlit in Snowflake, Snowpark |
| [tool-api-data-fetcher](tool-api-data-fetcher/) | Python stored procedure that fetches from a REST API via external access | External Access, Python Stored Procedures |
| [tool-secrets-rotation-aws](tool-secrets-rotation-aws/) | Snowflake Notebook: rotate key-pair and PAT credentials for service accounts with AWS Secrets Manager | Key-Pair Auth, PATs, AWS Secrets Manager, Notebooks |

### Guides and References

Documentation, patterns, and examples (no deploy/teardown).

| Directory | Description | Features |
|---|---|---|
| [guide-agent-multi-tenant](guide-agent-multi-tenant/) | Multi-tenant agent pattern with OAuth IdP + row-access policies | OAuth, Row Access Policies, Cortex Agents |
| [guide-cortex-search](guide-cortex-search/) | Cortex Search service creation, management, and querying | Cortex Search |
| [guide-csv-import](guide-csv-import/) | Load CSV files into Snowflake: one-time setup, repeatable imports, and automation | Stages, COPY INTO, File Formats |
| [guide-api-agent-context](guide-api-agent-context/) | Agent:Run REST API examples with execution context and three auth methods | Agent Run API, Key-Pair JWT Auth |
| [guide-coco-setup](guide-coco-setup/) | Cortex Code CLI on-ramp: install, guidance hierarchy, and first custom skill | Cortex Code, AGENTS.md |
| [guide-replication-workbook](guide-replication-workbook/) | Replication and failover SQL runbooks for Snowsight | Replication, Failover Groups |
| [tool-agent-config-diff](tool-agent-config-diff/) | Extract Cortex Agent specs for comparison and version control | DESC AGENT, RESULT_SCAN |
| [guide-agent-skills](guide-agent-skills/) | Agent skills as resource management: right tool, right budget, any client | Skills, Context Management, MCP |
| [guide-cortex-anthropic-redirect](guide-cortex-anthropic-redirect/) | Redirect Anthropic SDK calls to Snowflake Cortex with 3 code changes | Cortex REST API, Messages API, PAT Auth |
| [guide-coco-governance-general](guide-coco-governance-general/) | AI coding tool governance workshop (general, tool-agnostic) | managed-settings.json, CLAUDE.md, MDM |
| [guide-agent-governance](guide-agent-governance/) | Agent governance playbook: monitoring, RBAC, guardrails, cost controls, audit | Cortex Guard, CORTEX_AGENT_USAGE_HISTORY, Row Access Policies |
| [guide-mcp-auth](guide-mcp-auth/) | MCP server authentication walkthrough: PAT, OAuth + PKCE, RBAC, multi-tenant, enterprise IdP | Snowflake MCP, OAuth, PAT, RBAC |
| [guide-data-quality-governance](guide-data-quality-governance/) | Data quality governance: DMFs, tagging, masking, anomaly detection | Data Metric Functions, Tags, Masking Policies |
| [guide-semi-structured-pipeline](guide-semi-structured-pipeline/) | Bronze-to-gold pipeline architecture for semi-structured data with Dynamic Tables | Dynamic Tables, TRY_CAST, FLATTEN, INFER_SCHEMA, OpenFlow, DMFs |
| [guide-external-access-playbook](guide-external-access-playbook/) | External access patterns: network rules, EAI, secrets, OAuth | External Access Integration, Network Rules, Secrets |
| [guide-powerbi-live-query](guide-powerbi-live-query/) | Power BI DirectQuery at scale: interactive tables, hybrid tables, and optimization patterns | Interactive Tables, Interactive Warehouses, Hybrid Tables, Power BI SSO |
| [guide-powerbi-onelake-iceberg](guide-powerbi-onelake-iceberg/) | Power BI + Snowflake via OneLake and Iceberg: bi-directional access and Direct Lake mode | Iceberg Tables, OneLake, Catalog-Linked Databases, External Volumes |
| [guide-cost-drivers](guide-cost-drivers/) | Find your top 3 cost drivers: pruning, clustering, and search optimization before resizing | Warehouse Optimization, Clustering, Search Optimization, Pruning |

## Learning Journeys

Not sure where to start? Each journey connects 3-5 projects into a story: understand the use case, deploy an example, then learn the governance patterns.

| Journey | Story | Path | Start Here |
|---|---|---|---|
| **Agents** | Build an AI agent, deploy it to users, govern it, then connect via MCP | guide-coco-setup → demo-campaign-engine → demo-cortex-teams-agent → guide-agent-governance → guide-mcp-auth | [guide-coco-setup](guide-coco-setup/) |
| **FinOps** | Understand Cortex billing, track costs, set budgets and alerts | guide-cortex-anthropic-redirect → tool-cortex-rest-api-cost → tool-cortex-cost-intelligence → guide-cost-drivers | [guide-cortex-anthropic-redirect](guide-cortex-anthropic-redirect/) |
| **Data Quality** | Load data, build a pipeline, add quality gates and governance | guide-csv-import → guide-semi-structured-pipeline → demo-api-quickbooks-medallion → demo-dataquality-metrics → guide-data-quality-governance | [guide-csv-import](guide-csv-import/) |
| **External Access** | Call external APIs from Snowflake, manage secrets, harden for production | tool-api-data-fetcher → demo-api-quickbooks-medallion → tool-secrets-rotation-aws → guide-external-access-playbook | [tool-api-data-fetcher](tool-api-data-fetcher/) |
| **Search & RAG** | Build a Cortex Search service, then integrate it into a financial agent | guide-cortex-search → demo-cortex-financial-agents | [guide-cortex-search](guide-cortex-search/) |
| **BI Integration** | Connect Power BI via DirectQuery and OneLake/Iceberg | guide-powerbi-live-query → guide-powerbi-onelake-iceberg | [guide-powerbi-live-query](guide-powerbi-live-query/) |

---

## Quick Start

### Develop with Cortex Code

```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) <project-name>
cd sfe-public/<project-name>
cortex
```

Then tell Cortex Code: *"Help me get started with this project"*

The AI reads the project's AGENTS.md, understands the deployment steps, and walks you through everything -- from creating Snowflake objects to running the demo.

> New to Cortex Code? Start with [guide-coco-setup](guide-coco-setup/) to install and configure.

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
