# SFE Public

A curated collection of Snowflake demonstration projects, tools, and guides.
Each subdirectory is self-contained with its own documentation, deployment scripts, and cleanup.

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

| Directory | Description |
|---|---|
| [demo-cortex-teams-agent](demo-cortex-teams-agent/) | Snowflake Cortex Agents for Microsoft Teams & M365 Copilot |
| [demo-cortex-openai-enrichment](demo-cortex-openai-enrichment/) | AI-First Data Engineering: OpenAI + Snowflake Cortex |
| [demo-cortex-product-classification](demo-cortex-product-classification/) | Multi-method product classification showdown (SQL, Cortex AI, SPCS Vision) |
| [demo-dataquality-metrics](demo-dataquality-metrics/) | Data Quality Metrics & Reporting with DMFs and Streamlit |
| [demo-api-quickbooks-medallion](demo-api-quickbooks-medallion/) | QuickBooks API medallion architecture with Cortex AI enrichment and DQ monitoring |
| [demo-campaign-engine](demo-campaign-engine/) | Casino campaign recommendation engine with ML targeting and vector lookalike matching |

### Deployable Tools

Focused utilities with `deploy_all.sql` (or `deploy.sql`) and matching teardown.

| Directory | Description |
|---|---|
| [tool-cortex-cost-calculator](tool-cortex-cost-calculator/) | Cortex spend attribution dashboard with 12-month forecasting |
| [tool-replication-cost-calculator](tool-replication-cost-calculator/) | Streamlit DR Replication Cost Calculator for Business Critical |
| [tool-cortex-semantic-enhancer](tool-cortex-semantic-enhancer/) | AI-enhanced semantic view descriptions using Cortex |
| [tool-cortex-agent-chat](tool-cortex-agent-chat/) | React chat UI for Cortex Agents (REST API + key-pair JWT) |
| [tool-streamlit-contact-form](tool-streamlit-contact-form/) | Streamlit form that writes submissions to a Snowflake table |
| [tool-api-data-fetcher](tool-api-data-fetcher/) | Python stored procedure that fetches from a REST API via external access |
| [tool-agent-config-diff](tool-agent-config-diff/) | Extract Cortex Agent specs for comparison and version control |

### Guides and References

Documentation, patterns, and examples (no deploy/teardown).

| Directory | Description |
|---|---|
| [guide-agent-multi-tenant](guide-agent-multi-tenant/) | Multi-tenant agent pattern with OAuth IdP + row-access policies |
| [guide-cortex-search](guide-cortex-search/) | Cortex Search service creation, management, and querying |
| [guide-api-agent-context](guide-api-agent-context/) | Agent:Run REST API examples with execution context |
| [guide-coco-setup](guide-coco-setup/) | Cortex Code CLI on-ramp: install, guidance hierarchy, and first custom skill |
| [guide-slack-chart-patch](guide-slack-chart-patch/) | Chart and visualization support for the Cortex Agent + Slack quickstart |
| [guide-replication-workbook](guide-replication-workbook/) | Replication and failover SQL runbooks for Snowsight |

## Quick Start

### Path 1: Deploy in Snowsight (no local clone needed)

Most projects deploy entirely inside Snowflake -- the deploy script creates a Git Repository object, fetches from GitHub, and runs everything server-side.

1. Pick a demo or tool from the tables above
2. Open its `deploy_all.sql` (or `deploy.sql`) on GitHub and copy into a Snowsight worksheet
3. Click **Run All**
4. See the project README for usage instructions

### Path 2: Develop with Cortex Code (clone the repo)

If you want AI-assisted deployment or want to modify the code, clone the repo and use [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli):

```bash
git clone https://github.com/sfc-gh-miwhitaker/sfe-public.git
cd sfe-public/<project-name>
cortex
```

Then tell Cortex Code: *"Help me get started with this project"*

The full repo is under 4 MB. To clone only one project:

```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) <project-name>
```

### Guides

Open the guide directory and follow the README.

## Shared Infrastructure

Each deploy script creates the shared infrastructure it needs (using `IF NOT EXISTS`):

| Resource | Name | Purpose |
|---|---|---|
| Database | `SNOWFLAKE_EXAMPLE` | Shared demo database |
| Warehouse | `SFE_TOOLS_WH` | Shared compute (X-SMALL) |

Each project creates its own schema within `SNOWFLAKE_EXAMPLE`. No separate setup step is required.

## License

Each project may contain its own license. See individual project directories.
