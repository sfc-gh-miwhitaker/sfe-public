![Projects](https://img.shields.io/badge/Projects-34-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake SE Community Guides and Examples

Practical guides and runnable examples for Snowflake data pipelines, Cortex AI,
integrations, security, and cost governance.

**[Read online](https://sfc-gh-miwhitaker.github.io/sfe-public/)**
| [Browse projects](#projects) | [Get example files](#quick-start) | [Contribute](CONTRIBUTING.md)

Pair-programmed by SE Community + Cortex Code

> **No support is provided.** Reference and learning material, not a supported product.
> Check each guide's review date and feature limitations; validate before production use.

## Start Here

Pick a goal. Each project's README has its prerequisites and next steps.

| I need to... | Start with | Next steps |
| --- | --- | --- |
| **Connect an external tool to Snowflake** | [Integration guides](#integrations) | Pick your tool; guides are standalone. |
| **Build Snowflake data pipelines** | [Streams CDC workshop](demo-streams-cdc-workshop/) | Then [OpenTelemetry](guide-otel-to-snowflake/) or [AI spend ingestion](guide-ai-spend-consolidation/). |
| **Build a production Cortex Agent** | [Model-agnostic accuracy](guide-model-agnostic-accuracy/) | [Versioning](guide-cortex-agent-versioning/), [orchestration](guide-agent-to-agent-orchestration/), then [specialized tools](guide-cortex-agent-image-tool/). |
| **Govern Snowflake costs and usage** | [Cost visibility](guide-snowflake-cost-visibility/) | [AI controls](demo-cortex-ai-cost-controls/), [compute](guide-adaptive-compute/), [organization reporting](guide-org-reporting/), or [cross-platform AI spend](guide-ai-spend-consolidation/). |
| **Secure Snowflake and build an audit trail** | [Security guides](#security) | Pick the access boundary or audit requirement you need. |
| **Understand new Snowflake capabilities** | [Capability guides](#capabilities) | Pick a topic, or explore a [working application demo](#demos); check availability and review dates. |

## Quick Start

**Reading needs no installation.** Open a guide below or try the
[AI spend planning workbook](https://sfc-gh-miwhitaker.github.io/sfe-public/guide-ai-spend-consolidation/workbook.html)
in your browser.

**To work with the files**, clone the repository:

```bash
git clone https://github.com/sfc-gh-miwhitaker/sfe-public.git
cd sfe-public
```

For just one project, use the helper instead. It requires Bash and Git, not a
Snowflake connection. Review [the script](shared/get-project.sh) before running it:

```bash
curl --fail --silent --show-error --location https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh -o get-project.sh
bash get-project.sh --list
bash get-project.sh demo-streams-cdc-workshop
```

Open the selected project in your editor and follow its README. If using an AI
assistant, ask it to read the project's `AGENTS.md` where present, then say:
*"Help me get started with this project."* Developer hooks are optional and
separate; see [Contributing](CONTRIBUTING.md).

## Projects

Each project is listed once below. Some serve more than one goal in Start Here.

### Integrations

| Guide | What it helps you do | Topics |
| --- | --- | --- |
| [Cortex Code setup](guide-coco-setup/) | Install and configure Cortex Code, then build a first skill. | Cortex Code, skills |
| [Claude Desktop and Snowflake](guide-connecting-claude-snowflake/) | Understand connection and context options for Claude with Snowflake. | Claude, MCP |
| [Claude Code and SDK redirect](guide-claude-code-cortex-redirect/) | Route compatible CLI and SDK inference through Cortex REST APIs. | Claude Code, Cortex REST |
| [VS Code and Copilot](guide-vscode-copilot-cortex/) | Connect Copilot workflows to Snowflake tools and context. | VS Code, Copilot |
| [Microsoft Copilot Studio](guide-connecting-copilot-studio-snowflake/) | Choose among knowledge sources, Analyst, MCP, and REST integration. | Copilot Studio, MCP |
| [Power BI OAuth](guide-powerbi-oauth/) | Configure OAuth SSO and troubleshoot per-viewer identity. | Power BI, OAuth |
| [Salesforce zero copy](guide-salesforce-v2-zero-copy/) | Choose the right direction and connector for Salesforce zero-copy access. | Salesforce, zero copy |
| [Delta Sharing behind an IP allowlist](guide-delta-sharing-ip-allowlist/) | Consume a vendor Delta Sharing feed when the provider only accepts allowlisted IP addresses. | Delta Sharing, egress IPs |
| [Splunk audit ingestion](guide-snowflake-splunk-ingestion/) | Compare four patterns for getting Snowflake audit data into Splunk. | Splunk, audit logs |
| [Cube semantic layer](guide-cube-snowflake-semantic-layer/) | Configure Cube authentication, pre-aggregations, and semantic-view synchronization. | Cube, semantic layer |
| [Advertising platforms](guide-ad-platform-integrations/) | Separate Google and Meta outbound activation from inbound reporting. | Google Ads, Meta Ads |
| [Shopify through Openflow](guide-openflow-shopify-multistore/) | Plan multi-store ingestion with explicit connector limitations and cost considerations. | Shopify, Openflow |
| [Shopify Bulk API with Cortex Code](guide-shopify-bulk-api-coco/) | Build and qualify a deterministic Shopify ingestion pipeline. | Shopify, Bulk API |

### Pipelines and Cost Governance

| Guide | What it helps you do | Topics |
| --- | --- | --- |
| [Debezium to Snowflake](guide-debezium-to-snowflake/) | Land database changes through Kafka and model them in Snowflake. | Debezium, Kafka, CDC |
| [OpenTelemetry to Snowflake](guide-otel-to-snowflake/) | Choose an ingestion path for external logs, metrics, and traces. | OpenTelemetry, observability |
| [AI spend consolidation](guide-ai-spend-consolidation/) | Model cross-platform AI spend and adoption without mixing incompatible billing measures. | AI FinOps, identity, workbook |
| [Snowflake cost visibility](guide-snowflake-cost-visibility/) | Use budgets, usage views, and resource monitors appropriately. | Credits, budgets |
| [Adaptive compute](guide-adaptive-compute/) | Configure adaptive warehouses and evaluate their workload fit. | Warehouses, performance |
| [Organization reporting](guide-org-reporting/) | Choose the correct access path for cross-account reporting. | Organization usage, credits |

### Cortex Agents

| Guide | What it helps you do | Topics |
| --- | --- | --- |
| [Model-agnostic accuracy](guide-model-agnostic-accuracy/) | Improve answer quality through semantic models, instructions, and evaluation. | Accuracy, semantic views |
| [Cortex Agent versioning](guide-cortex-agent-versioning/) | Promote and roll back agent configurations with versions and aliases. | Versioning, GitHub |
| [Agent-to-agent orchestration](guide-agent-to-agent-orchestration/) | Choose supported mechanisms for delegating work between agents. | Orchestration, MCP |
| [Image-generation tools](guide-cortex-agent-image-tool/) | Understand the custom-tool bridge for agent-driven image generation. | Custom tools, images |

### Security

| Guide | What it helps you do | Topics |
| --- | --- | --- |
| [MCP role controls](guide-snowflake-mcp-role-controls/) | Separate primary-role OAuth boundaries from secondary-role restrictions. | MCP, OAuth, roles |
| [Cortex Search access control](guide-cortex-search-access-control/) | Choose filtering or service-isolation patterns for search access. | Cortex Search, RBAC |
| [CoWork-only users](guide-cowork-only-users/) | Provision business users with constrained interfaces and access. | CoWork, provisioning |
| [Firewall allowlisting](guide-snowflake-firewall-allowlist/) | Distinguish outbound hostname rules from Snowflake egress IP rules. | Firewalls, networking |
| [Cortex Code access control](guide-cortex-code-access-control/) | Restrict access and inspect usage during a progressive rollout. | Cortex Code, roles |

### Capabilities

| Guide | What it helps you do | Topics |
| --- | --- | --- |
| [Horizon Context and Cortex Sense](guide-horizon-context-catalog/) | Understand the context stack and its documented boundaries. | Catalog, context |
| [Universal data sharing](guide-universal-data-sharing/) | Compare sharing capabilities for different partners and engines. | Sharing, interoperability |
| [CoWork features](guide-cowork-easter-eggs/) | Find less-visible CoWork capabilities, prerequisites, and limitations. | CoWork, productivity |

### Demos

| Demo | What you build | Topics |
| --- | --- | --- |
| [Streams CDC workshop](demo-streams-cdc-workshop/) | Practice transactional change processing, reconciliation, and stream recovery. | Streams, Tasks, CDC |
| [Cortex AI cost controls](demo-cortex-ai-cost-controls/) | Explore credit attribution and native quota status in a dashboard. | Cortex AI, quotas |
| [Restaurant Recovery Explorer](demo-restaurant-recovery-explorer/) | Explore synthetic guest losses, matched restaurants, and evidence-backed action briefs through a clickable map. | Applications, synthetic data, operations |

## First-Time Setup

No setup is required to read the guides. Contributor tooling and optional Git hooks
are documented in [Contributing](CONTRIBUTING.md#developer-setup).

## License

Apache License 2.0. See [LICENSE](LICENSE) and each project directory.
