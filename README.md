# SFE Public

A curated collection of Snowflake demonstration projects, tools, and guides.
Each subdirectory is self-contained with its own documentation, deployment scripts, and cleanup.

## Projects

### Demos

Full demonstration projects with `deploy_all.sql` and `teardown_all.sql`.

| Directory | Description |
|---|---|
| [demo-cortex-teams-agent](demo-cortex-teams-agent/) | Snowflake Cortex Agents for Microsoft Teams & M365 Copilot |
| [demo-cortex-openai-enrichment](demo-cortex-openai-enrichment/) | AI-First Data Engineering: OpenAI + Snowflake Cortex |
| [demo-cortex-product-classification](demo-cortex-product-classification/) | Multi-method product classification showdown (SQL, Cortex AI, SPCS Vision) |
| [demo-dataquality-metrics](demo-dataquality-metrics/) | Data Quality Metrics & Reporting with DMFs and Streamlit |

### Deployable Tools

Focused utilities with `deploy.sql` and `teardown.sql`.

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
| [guide-slack-chart-patch](guide-slack-chart-patch/) | Chart and visualization support for the Cortex Agent + Slack quickstart |
| [guide-replication-workbook](guide-replication-workbook/) | Replication and failover SQL runbooks for Snowsight |

## Quick Start

### Demos and deployable tools

1. Run `shared/sql/00_shared_setup.sql` in Snowsight (first time only -- creates shared database and warehouse)
2. Pick a project from the tables above
3. Open its `deploy_all.sql` or `deploy.sql` in Snowsight
4. Click **Run All**
5. See the project README for detailed instructions

### Guides

Open the guide directory and follow the README.

## Shared Infrastructure

All deployable projects use common infrastructure created by [`shared/sql/00_shared_setup.sql`](shared/sql/00_shared_setup.sql):

| Resource | Name | Purpose |
|---|---|---|
| Database | `SNOWFLAKE_EXAMPLE` | Shared demo database |
| Warehouse | `SFE_TOOLS_WH` | Shared compute (X-SMALL) |

Each project creates its own schema within `SNOWFLAKE_EXAMPLE`.

## License

Each project may contain its own license. See individual project directories.
