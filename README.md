![Projects](https://img.shields.io/badge/Projects-35-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Solutions Engineering -- Public Examples

Snowflake demos, tools, and guides -- each self-contained with deployment scripts, teardown, and AI-assisted development via [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli). Clone a project, run `cortex`, and let the AI guide you through deployment and usage.

> **No support is provided.** All code is shared for reference and learning. Review, test, and modify thoroughly before any production use.

```mermaid
quadrantChart
    title Find Your Starting Point
    x-axis Simpler --> More Complex
    y-axis Traditional --> AI-Native
    quadrant-1 AI Frontier
    quadrant-2 Deep Dive
    quadrant-3 Foundations
    quadrant-4 Quick Wins

    guide-csv-import: [0.10, 0.10]
    guide-cost-drivers: [0.18, 0.15]
    guide-replication-workbook: [0.25, 0.12]
    guide-powerbi-live-query: [0.55, 0.18]
    guide-powerbi-onelake-iceberg: [0.65, 0.22]
    guide-semi-structured-pipeline: [0.35, 0.20]
    guide-external-access-playbook: [0.48, 0.28]
    tool-streamlit-contact-form: [0.20, 0.30]
    tool-api-data-fetcher: [0.30, 0.25]
    tool-agent-config-diff: [0.40, 0.45]
    demo-dataquality-metrics: [0.50, 0.35]
    demo-api-quickbooks-medallion: [0.60, 0.38]
    demo-cortex-openai-enrichment: [0.58, 0.52]
    tool-secrets-rotation-aws: [0.42, 0.32]
    guide-data-quality-governance: [0.45, 0.40]
    guide-cortex-anthropic-redirect: [0.22, 0.55]
    guide-coco-setup: [0.15, 0.62]
    guide-coco-governance-general: [0.28, 0.68]
    demo-coco-governance-github: [0.38, 0.72]
    guide-cortex-search: [0.32, 0.58]
    tool-cortex-semantic-enhancer: [0.40, 0.60]
    tool-cortex-cost-intelligence: [0.35, 0.55]
    tool-cortex-rest-api-cost: [0.28, 0.48]
    tool-dr-cost-agent: [0.48, 0.65]
    guide-agent-skills: [0.52, 0.75]
    guide-api-agent-context: [0.58, 0.70]
    guide-agent-governance: [0.62, 0.78]
    guide-agent-multi-tenant: [0.68, 0.72]
    guide-mcp-auth: [0.72, 0.68]
    demo-cortex-teams-agent: [0.65, 0.85]
    demo-cortex-financial-agents: [0.78, 0.82]
    demo-campaign-engine: [0.72, 0.88]
    demo-agent-multicontext: [0.88, 0.92]
    glaze-and-classify: [0.92, 0.80]
```

---

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

Not sure where to start? Each journey connects 3-4 projects into a story: understand the use case, deploy an example, then learn the governance patterns.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'lineColor': '#4a90d9'}}}%%
flowchart TB

  subgraph agents ["Agents — Build, deploy, and govern AI agents"]
    direction LR
    A1(["guide-coco-setup"]):::guide --> A2(["demo-campaign-engine"]):::demo
    A2 --> A3(["demo-cortex-teams-agent"]):::demo
    A3 --> A4(["guide-agent-governance"]):::guide
    A4 --> A5(["guide-mcp-auth"]):::guide
  end

  subgraph finops ["FinOps — Understand billing, track costs, set budgets"]
    direction LR
    F1(["guide-cortex-anthropic-redirect"]):::guide --> F2(["tool-cortex-rest-api-cost"]):::tool
    F2 --> F3(["tool-cortex-cost-intelligence"]):::tool
    F3 --> F4(["guide-cost-drivers"]):::guide
  end

  subgraph dq ["Data Quality — Load data, add quality gates, govern"]
    direction LR
    D1(["guide-csv-import"]):::guide --> D2(["guide-semi-structured-pipeline"]):::guide
    D2 --> D3(["demo-api-quickbooks-medallion"]):::demo
    D3 --> D4(["demo-dataquality-metrics"]):::demo
    D4 --> D5(["guide-data-quality-governance"]):::guide
  end

  subgraph ext ["External Access — Call APIs, manage secrets, harden"]
    direction LR
    E1(["tool-api-data-fetcher"]):::tool --> E2(["demo-api-quickbooks-medallion"]):::demo
    E2 --> E3(["tool-secrets-rotation-aws"]):::tool
    E3 --> E4(["guide-external-access-playbook"]):::guide
  end

  subgraph search ["Search & RAG — Build search, integrate into agents"]
    direction LR
    S1(["guide-cortex-search"]):::guide --> S2(["demo-cortex-financial-agents"]):::demo
  end

  subgraph bi ["BI Integration — Connect Power BI to Snowflake"]
    direction LR
    B1(["guide-powerbi-live-query"]):::guide --> B2(["guide-powerbi-onelake-iceberg"]):::guide
  end

  classDef demo fill:#e8364f,color:#fff,stroke:#c12a3f,font-weight:bold
  classDef tool fill:#4a90d9,color:#fff,stroke:#3a7bc8,font-weight:bold
  classDef guide fill:#2ecc71,color:#fff,stroke:#27ae60,font-weight:bold
```

> Legend: 🔴 Demo &nbsp; 🔵 Tool &nbsp; 🟢 Guide

| Journey | Story | Start Here |
|---|---|---|
| **Agents** | Build an AI agent, deploy it to users, govern it, then connect via MCP | [guide-coco-setup](guide-coco-setup/) |
| **FinOps** | Understand Cortex billing, track costs, set budgets and alerts | [guide-cortex-anthropic-redirect](guide-cortex-anthropic-redirect/) |
| **Data Quality** | Load data, build a pipeline, add quality gates and governance | [guide-csv-import](guide-csv-import/) |
| **External Access** | Call external APIs from Snowflake, manage secrets, harden for production | [tool-api-data-fetcher](tool-api-data-fetcher/) |
| **Search & RAG** | Build a Cortex Search service, then integrate it into a financial agent | [guide-cortex-search](guide-cortex-search/) |
| **BI Integration** | Connect Power BI via DirectQuery and OneLake/Iceberg | [guide-powerbi-live-query](guide-powerbi-live-query/) |

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
