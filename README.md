![Projects](https://img.shields.io/badge/Projects-18-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake SE Community Guides and Examples

Practical guides and reference examples for Snowflake data pipelines, Cortex AI,
integrations, security, and cost governance.

**[Read online](https://sfc-gh-miwhitaker.github.io/sfe-public/)**
| [Browse projects](#projects) | [Get example files](#quick-start) | [Contribute](CONTRIBUTING.md)

Pair-programmed by SE Community + Cortex Code

> **No support is provided.** Reference and learning material, not a supported product.
> Check each guide's review date and feature limitations; validate before production use.

Guides retire at most 60 days after substantive verification unless explicitly
reverified. Legacy review baselines are labeled separately. See the
[verification and retirement policy](CONTRIBUTING.md#verification-and-retirement).

## Start Here

Pick a goal. Each project's README has its prerequisites and next steps.

| I need to... | Start with | Next steps |
| --- | --- | --- |
| **Connect an external tool to Snowflake** | [Integration guides](#integrations) | Pick your tool; guides are standalone. |
| **Build Snowflake data pipelines** | [Debezium CDC](guide-debezium-to-snowflake/) | Or [OpenTelemetry](guide-otel-to-snowflake/) and [AI spend ingestion](guide-ai-spend-consolidation/), depending on your source. |
| **Build a production Cortex Agent** | [Model-agnostic accuracy](guide-model-agnostic-accuracy/) | Then [AI access control](guide-cortex-access-control/) for access and usage boundaries. |
| **Govern Snowflake costs and usage** | [Cost visibility](guide-snowflake-cost-visibility/) | [AI access and limits](guide-cortex-access-control/), [organization reporting](guide-org-reporting/), or [cross-platform AI spend](guide-ai-spend-consolidation/). |
| **Secure Snowflake and build an audit trail** | [Security guides](#security) | Pick the access boundary or audit requirement you need. |
| **Understand new Snowflake capabilities** | [Capability guides](#capabilities) | Pick a topic; check availability and review dates. |

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
bash get-project.sh guide-ai-spend-consolidation
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
| [External coding harnesses with CoCo](guide-external-harness-coco/) | Delegate bounded Snowflake work from Claude Code or Codex through native MCP or AI Kit, with explicit authority and evidence. | CoCo, Claude Code, Codex, MCP, delegation |
| [Salesforce zero copy](guide-salesforce-v2-zero-copy/) | Choose the right direction and connector for Salesforce zero-copy access. | Salesforce, zero copy |
| [Delta Sharing behind an IP allowlist](guide-delta-sharing-ip-allowlist/) | Consume a vendor Delta Sharing feed when the provider only accepts allowlisted IP addresses. | Delta Sharing, egress IPs |
| [Cube semantic layer](guide-cube-snowflake-semantic-layer/) | Configure Cube authentication, pre-aggregations, and semantic-view synchronization. | Cube, semantic layer |
| [Advertising platforms](guide-ad-platform-integrations/) | Separate Google and Meta outbound activation from inbound reporting. | Google Ads, Meta Ads |
| [Dozens of Shopify stores into Snowflake](guide-shopify-multistore-snowflake/) | Land orders, line items, shipments, and fulfillments from many stores via either the Openflow connector or a native Bulk API pipeline, publishing one shared analytics contract. | Shopify, Openflow, Bulk API, Dynamic Tables |

### Pipelines and Cost Governance

| Guide | What it helps you do | Topics |
| --- | --- | --- |
| [Debezium to Snowflake](guide-debezium-to-snowflake/) | Land database changes through Kafka and model them in Snowflake. | Debezium, Kafka, CDC |
| [OpenTelemetry to Snowflake](guide-otel-to-snowflake/) | Choose an ingestion path for external logs, metrics, and traces. | OpenTelemetry, observability |
| [AI spend consolidation](guide-ai-spend-consolidation/) | Model cross-platform AI spend and adoption without mixing incompatible billing measures. | AI FinOps, identity, workbook |
| [Snowflake cost visibility](guide-snowflake-cost-visibility/) | Use budgets, usage views, and resource monitors appropriately. | Credits, budgets |
| [Organization reporting](guide-org-reporting/) | Choose the correct access path for cross-account reporting. | Organization usage, credits |

### Cortex Agents

| Guide | What it helps you do | Topics |
| --- | --- | --- |
| [Model-agnostic accuracy](guide-model-agnostic-accuracy/) | Improve answer quality through semantic models, instructions, and evaluation. | Accuracy, semantic views |

### Security

| Guide | What it helps you do | Topics |
| --- | --- | --- |
| [MCP role controls](guide-snowflake-mcp-role-controls/) | Separate primary-role OAuth boundaries from secondary-role restrictions. | MCP, OAuth, roles |
| [Cortex AI access control](guide-cortex-access-control/) | Decide who gets which part of the Cortex surface, apply and verify the grants, and monitor usage. | Cortex, RBAC, roles, models, spend limits |
| [Choose approved AI models](guide-cortex-model-policy/) | Keep an explicit approved-model list, remove broad access, and verify that excluded and newly released models stay opt-in. | Model approval, model filtering, RBAC, CoCo |

### Capabilities

| Guide | What it helps you do | Topics |
| --- | --- | --- |
| [Horizon Context and Cortex Sense](guide-horizon-context-catalog/) | Understand the context stack and its documented boundaries. | Catalog, context |
| [CoWork features](guide-cowork-easter-eggs/) | Find less-visible CoWork capabilities, prerequisites, and limitations. | CoWork, productivity |
| [Snowflake ML lifecycle](guide-snowflake-ml-lifecycle/) | Evaluate Snowflake ML end to end against an AWS stack: design, monitoring, serving bake-off, registry, and cost. | ML, Model Registry, SPCS, monitoring |

## First-Time Setup

No setup is required to read the guides. Contributor tooling and optional Git hooks
are documented in [Contributing](CONTRIBUTING.md#developer-setup).

## License

Apache License 2.0. See [LICENSE](LICENSE) and each project directory.
