![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2026--10--09-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Horizon Context + Cortex Sense: The Catalog Pivot Explained

Snowflake's [November 2025 definitive agreement to acquire Select Star's team and platform technology](https://www.snowflake.com/en/blog/snowflake-acquire-select-star/), combined with the Summit 2026 announcements of [Horizon Context](https://www.snowflake.com/en/blog/horizon-context-governed-context/) and [Cortex Sense](https://www.snowflake.com/en/blog/enterprise-ai-agents-grounded-context/), represents a significant shift in how data context reaches AI agents. This guide explains the full stack, what changed for customers who built security boundaries around semantic views and agents, and what questions remain open.

**Audience:** SEs fielding questions from customers who have deployed Cortex Agents, semantic views, or third-party data catalogs — and now need to understand the new model.
**Created:** 2026-07-09 | **Expires:** 2026-10-09 | **Status:** ACTIVE

Pair-programmed by SE Community + Cortex Code

> **No support provided.** Reference only; validate before production use.

> **Availability caveat.** The features in this guide are moving fast. Horizon Context metadata connectors were announced in **private preview**; Cortex Sense was announced to enter private preview in mid-July 2026, but current account access should be confirmed with the Snowflake account team. Every availability status is noted inline. Re-verify before quoting specific claims to customers. Benchmark figures are from Snowflake's internal tests and do not represent guaranteed customer results.

---

## Start Here

Use this guide in three passes:

1. Read **The Three-Layer Stack** to separate Horizon Catalog, Horizon Context, and Cortex Sense.
2. Read **The Security Boundary Question** before discussing regulated or least-privilege deployments.
3. Check **Availability Summary** before quoting preview status or interoperability support.

Treat announced roadmap behavior, current product availability, and documented Cortex Agent controls as separate facts. This guide marks the boundaries explicitly.

Ready to act? Use [What Can I Do Now?](docs/01-WHAT-CAN-I-DO-NOW.md) for a capability-by-capability checklist and 30-day action plan.

---

## Vocabulary

| Term | Plain meaning |
|---|---|
| **Horizon Catalog** | Snowflake's built-in data governance and discovery layer. Covers Snowflake-native objects: tables, views, lineage, access policies, tags, and documentation. Has always existed; Horizon Context builds on top of it. |
| **Horizon Context** | Announced Summit 2026. Extends Horizon Catalog to pull metadata from systems outside Snowflake — BI tools, databases, data pipelines — and enriches it into a governed semantic foundation. |
| **Metadata Connector** | A built-in integration that ingests schemas, query logs, and dashboard definitions from an external system into Horizon Catalog. |
| **Select Star** | A data catalog company whose team and platform technology Snowflake announced an agreement to acquire in November 2025. Known for cross-system lineage and usage-based popularity signals. Its integrations are intended to expand Horizon Catalog. |
| **Semantic View** | A Snowflake object that defines business metrics, dimensions, and relationships over raw tables. Used by Cortex Analyst to answer natural-language questions. |
| **Cortex Sense** | Announced Summit 2026 for private preview in mid-July 2026. A managed context layer demonstrated with CoCo that retrieves relevant catalog context without CoCo having to inspect every table manually. Confirm current account access with the Snowflake account team. |
| **Cortex Analyst** | The Snowflake service that generates SQL from natural language using a semantic view as its business logic layer. |
| **CoWork** | Snowflake's business-user-facing agent interface, rebranded from Snowflake Intelligence at Summit 2026. Coordinates specialist agents; Cortex Sense powers its context retrieval. |
| **OpenLineage** | An open standard for lineage metadata. Systems like Apache Airflow can push lineage directly into Horizon Catalog via the OpenLineage API. |
| **Apache Ossie (Incubating)** | The vendor-neutral semantic specification formerly called Open Semantic Interchange (OSI). Accepted into the Apache Incubator under its new name in July 2026. |
| **RBAC** | Role-based access control. Governs which Snowflake roles can access which objects. |
| **GA / Public Preview / Private Preview** | Snowflake maturity labels. GA = production-ready. Public Preview = available to all accounts, may change. Private Preview = limited access, must request. |

---

## The Problem Catalogs Were Built to Solve

In 2026, your head of sales sees $14.2 million in Q3 revenue. Your CFO sees $12.8 million. Both asked an AI agent the same question this morning. This is the metric drift problem — business logic scattered across a BI model only one team owns, a calculation buried in a dashboard, instructions hardcoded into an LLM prompt. *(Opening scenario from [Snowflake's Horizon Context announcement](https://www.snowflake.com/en/blog/horizon-context-governed-context/).)*

Traditional data catalogs (Alation, Collibra, and their predecessors) were built to solve a version of this: make it possible to find your data and understand what it means. They built inventories. They worked well for human data stewards.

They were not designed to activate business meaning automatically during an AI interaction. In Snowflake's published CoCo and Cortex Sense design, relevant context is retrieved at query time rather than discovered through repeated table inspection.

That gap — passive inventory vs active runtime context — is what Snowflake's current catalog pivot is about.

---

## What Select Star Brought

Select Star was a data catalog platform that did two things particularly well:

1. **Cross-system lineage.** It traced data from source databases through transformation pipelines into BI dashboards — not just within Snowflake, but across PostgreSQL, MySQL, Tableau, Power BI, dbt, and Airflow.

2. **Usage-based popularity signals.** Rather than relying on manual tagging, it used actual query logs and access patterns to identify which data assets were authoritative and trusted.

[Snowflake announced a definitive agreement to acquire the Select Star team and platform technology](https://www.snowflake.com/en/blog/snowflake-acquire-select-star/) in November 2025. The cited announcement says these integrations will help expand Horizon Catalog's view of enterprise data; it does not establish that the transaction closed. No public announcement has been made about the Select Star standalone product roadmap.

---

## The Three-Layer Stack

Understanding the current architecture requires seeing all three layers together:

```mermaid
flowchart TD
    HC["Horizon Catalog\n(always existed)\nSnowflake-native objects:\ntables, views, lineage,\naccess policies, tags"]
    HCtx["Horizon Context\n(Summit 2026 — Private Preview)\nExtends to external systems:\nBI tools, databases, pipelines\nCollect → Enrich → Activate"]
    CS["Cortex Sense\n(Summit 2026 — announced for Private Preview mid-July)\nManaged context activation\ndemonstrated with CoCo"]

    HC --> HCtx --> CS

    SS["Select Star\ntechnology"] -.->|"being integrated into"| HCtx
    SV["Semantic Views\n(GA)\ngold standard signal"] -.->|"authoritative input"| CS
```

Each layer has a distinct job:
- **Horizon Catalog** — the governed inventory of everything Snowflake knows about your data
- **Horizon Context** — expands that inventory to external systems and enriches raw metadata into business meaning
- **Cortex Sense** — was designed to make enriched context active at query time for CoCo queries, retrieving relevant context instead of inspecting the estate table by table

---

## Horizon Context in Detail

Horizon Context organizes its work into three phases.

### Collect

Horizon Context pulls metadata from systems outside Snowflake using built-in metadata connectors. Wave 1 connectors (all in **private preview** [as announced June 2026](https://www.snowflake.com/en/blog/horizon-context-governed-context/)):

| Connector | What it collects |
|---|---|
| PostgreSQL | Schemas, query logs |
| Microsoft SQL Server | Schemas, query logs |
| Tableau | Dashboard definitions, calculated fields |
| Power BI | Report definitions, measures |
| dbt | Model definitions, column descriptions, lineage |

Additionally, the **OpenLineage API** ([public preview](https://www.snowflake.com/en/blog/horizon-context-governed-context/)) allows systems like Apache Airflow to push lineage data directly into Horizon Catalog without a pull connector.

**[Apache Ossie (Incubating)](https://www.snowflake.com/en/blog/apache-ossie-open-semantic-interchange-incubator/)** — formerly Open Semantic Interchange (OSI) — defines a vendor-neutral format for exchanging semantic metadata across catalog vendors, BI tools, query engines, and AI agents. The [June 2026 Horizon Context announcement](https://www.snowflake.com/en/blog/horizon-context-governed-context/) cited 54 participating vendors; the July Apache update describes the coalition as more than 50 organizations.

### Enrich

Once collected, raw metadata is enriched into usable business context:

- **End-to-end column-level lineage** — stitched together from Snowflake query logs, external system logs, BI definitions, and OpenLineage feeds
- **Popularity signals** — query and access frequency used to identify which assets are authoritative vs experimental
- **AI-generated documentation** — table and column descriptions generated from metadata (and optionally sample data)
- **Semantic Views** — the governed business definition layer. [Semantic View Autopilot](https://docs.snowflake.com/en/user-guide/views-semantic/creating-with-snowsight) can use example SQL and ingest Tableau `.twb`, `.twbx`, `.tds`, and `.tdsx` files. [Power BI ingestion became GA on August 18, 2026](https://docs.snowflake.com/en/release-notes/2026/other/2026-08-18-semantic-views-power-bi-ingestion-ga) and supports `.pbit` and `.pbix`; report-level measures and time-intelligence functions are not yet fully supported.

### Activate

Enriched context is only valuable if it reaches the AI at the right moment:

- **Universal Search** — CoCo's context retrieval uses hybrid keyword + semantic search, filtered by access control policies, ranked by popularity
- **Automatic semantic view discovery** — when asked a data question, CoCo searches for and uses relevant semantic views, falling back to direct table access if none exist
- **Semantic View interoperability** — semantic views exposed via MCP allow Claude, Cursor, and other MCP clients to query Snowflake data with governed business logic. Power BI (private preview, coming soon), Excel (private preview, coming soon), ThoughtSpot (early access), and Looker (preview) are expanding the ecosystem.

---

## Cortex Sense: The Runtime Activation Layer

Horizon Context builds the enriched catalog. Cortex Sense is the managed layer Snowflake demonstrated activating that context for CoCo queries. Public sources do not establish transparent Cortex Sense injection into every Cortex Agent, third-party agent, or arbitrary AI request.

### Why It Exists

Snowflake's own product team found that even with Semantic View Autopilot, they had covered [fewer than 5% of their 9,685 internal tables](https://www.snowflake.com/en/blog/enterprise-ai-agents-grounded-context/) with semantic views. Any query that fell outside that 5% either got a wrong answer or no answer. Tables created two weeks ago have no semantic view. Cortex Sense is designed to fill that gap.

### How It Works

Cortex Sense builds a working model of your data estate automatically from signals your organization already produces:
- Query history from Snowflake and connected external systems
- Object metadata and table structures
- BI dashboard definitions (Power BI, Tableau) via Horizon Context connectors
- Semantic views — treated as the authoritative, highest-ranked signal

Rather than injecting the full catalog into every prompt (expensive, slow, and often wrong), Sense retrieves only the context relevant to the specific query. It ranks candidates by relevance, authority, popularity, and freshness.

### Accuracy and Cost (Snowflake Internal Benchmark)

Snowflake published the following results from [internal testing on their own product analytics data in June 2026](https://www.snowflake.com/en/blog/enterprise-ai-agents-grounded-context/). These are internal benchmarks; they do not represent guaranteed results on customer workloads.

| Setup | Accuracy |
|---|---|
| Frontier coding agent with direct SQL access (no context layer) | ~24% |
| CoCo with Cortex Sense | ~86% |

Snowflake's blog states accuracy "improved from 24.1% to 86.3%." An intermediate data point for vanilla CoCo is visible in the chart in the blog post but is not stated in the text; it is not quoted here to avoid misrepresentation.

Cost comparison on the same benchmark:

| Setup | Estimated cost per query |
|---|---|
| Frontier agent (manually inspecting tables via DESCRIBE) | ~$1.76 |
| CoCo + Cortex Sense | ~$0.59 |

The cost reduction comes from eliminating the agent's need to run `DESCRIBE TABLE` on dozens of objects to figure out what exists. Sense tells it where to look. Note: there is an upfront one-time indexing cost when Sense first ingests your data estate; Snowflake's blog states this is recoverable over time through lower per-query costs.

### Self-Correcting Evaluation Loop

Because Sense builds its understanding automatically rather than from hand-curated definitions, it includes a mechanism to surface and resolve conflicts:

- When evaluation queries fail, Sense reflects on why and attempts to update its own model
- When it detects conflicting definitions (e.g., multiple teams computing "daily active users" differently), it surfaces the conflict to the admin and asks them to resolve it in natural language
- Evaluation inputs come from three sources: your own gold-standard benchmark queries, end-user feedback, and Sense's own suggestions for areas where its coverage is thin

### Announced Private-Preview Access Model

From [Snowflake's official blog (June 30, 2026)](https://www.snowflake.com/en/blog/enterprise-ai-agents-grounded-context/):

> *"Cortex Sense will only ingest metadata and usage patterns, not your actual data rows. But like all other Snowflake objects, access will be scoped by role through Snowflake's existing governance. We're starting our private preview soon by allowing users to specify a single role that will get access to all of Cortex Sense, and will plan to expand to per-role contexts in the future, so your marketing team and finance team will get access to different contexts."*

**Announced initial model:** One designated role would receive access to all Cortex Sense context, with per-role context differentiation planned for the future. The June announcement does not by itself confirm current account availability; verify access and current behavior with the Snowflake account team.

---

## The Security Boundary Question

This is the section most customers with existing deployments will care about most.

### The Architecture Many Customers Built

Security-conscious customers — particularly in financial services, healthcare, and regulated industries — built a deliberate two-checkpoint model:

```text
Layer 1: RBAC
  The calling role's access scope.
  Controls what data the user (and agents acting as the user)
  can physically query.

    ↓

Layer 2: Semantic view as explicit tool configuration
  The agent is configured to use only sv_regional_sales.
  Even though the analyst role has SELECT on finance.*,
  the agent's declared Analyst tool is the semantic view.
```

This gave customers two independently auditable checkpoints: the role's data privileges and the agent's declared tools. Tool configuration narrows the resources the agent is designed to use, but it is not a replacement for least-privilege RBAC.

### What Changes With Cortex Sense

**What does NOT change:**

- RBAC still governs what data the agent can query. Sense ingests metadata and usage patterns only — not data rows. An agent cannot access data its role cannot reach.
- Semantic views are still supported as explicit tool configurations for Cortex Agents.
- Snowflake [states that governance policies follow context](https://www.snowflake.com/en/blog/horizon-context-governed-context/): *"role-based access control policies and row-level masking follow the context: every tool, every query and every AI response."*

**What is different:**

In Snowflake's published CoCo design, Cortex Sense retrieves context from across the catalog at query time, ranked by relevance, authority, popularity, and freshness. CoCo receives a richer, algorithmically assembled context rather than inspecting the estate table by table. Public sources do not establish the same retrieval path for every configured Cortex Agent.

The June 2026 announcement described an initial private-preview model in which one designated role would receive access to all Cortex Sense context, with per-role contexts planned for the future. It did not document whether Cortex Sense retrieval for a configured Cortex Agent is further constrained by that agent's declared tool resources.

Keep these controls separate:

- **Execution identity:** Cortex Agents determine permissions from the querying user's default role, not the role currently active in the session.
- **Configured tools:** The default role must have privileges on each tool and its underlying resources. Explicit Cortex Analyst and Cortex Search resources narrow those tools, but tool configuration is not a universal execution ceiling: SQL execution, code execution, functions, and generic tools can act within their own definitions and the default role's privileges.
- **Inaccessible tools:** By default, `orchestration.tool_not_accessible: accept` lets a run continue with accessible configured tools and emits warnings for inaccessible named tools. Set it to `reject` when every named tool must be accessible before a run starts. This setting does not grant privileges.
- **Agent privilege ceiling:** [Restricted Session Scope](https://docs.snowflake.com/en/user-guide/restricted-session-scope) can limit what agent-active sessions may do, intersecting with RBAC. It does not establish or document Cortex Sense's context-retrieval boundary.

**The question Snowflake has not yet answered publicly:**

> *Does Cortex Sense context retrieval respect an agent's configured tool scope (e.g., limited to `sv_regional_sales`), or does it operate at the calling user's full RBAC role scope?*

Snowflake's blog states access is scoped by role. It does not specify that Sense context is scoped to configured agent tools. If your use case requires that an agent not only be unable to query certain data but be unaware of its existence, this distinction matters. **Raise this question with your Snowflake account team before enabling Cortex Sense on sensitive workloads.**

### The Related Agent Identity Risk

Separately from Sense, [Snowflake's Cortex Agent access-control documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-setup) defines the execution identity, and [P0 Security's April 2026 research](https://p0.dev/blog/when-your-snowflake-ai-agent-can-query-everything-you-can-query/) discusses its security implications:

> Cortex Agents determine permissions from the **querying user's default role**, not the role currently active in the session. That default role also needs privileges on the agent's configured tools and underlying resources.

This is not a new risk introduced by Horizon Context or Cortex Sense. It is a pre-existing design characteristic of how Cortex Agents execute. The practical control is a purpose-built default role, optionally paired with Restricted Session Scope for agent-active sessions.

### Practical Guidance

For customers navigating this:

| Use case | Recommended approach |
|---|---|
| Discovery, analytics, CoWork queries | Enable Cortex Sense. This is what it is designed for. |
| Regulated workload with auditability requirement | Keep explicit semantic view tool configuration, set `tool_not_accessible` to `reject` when all declared tools are mandatory, and do not treat Sense as a scope control. |
| Any agent deployment | Use a purpose-built, minimal-privilege default role; consider Restricted Session Scope as an additional ceiling. |
| MCP-connected agents | Inventory every downstream system that can receive agent output. The data path extends beyond the warehouse. |

---

## Governance: What Snowflake Claims

From the [Horizon Context blog (June 2, 2026)](https://www.snowflake.com/en/blog/horizon-context-governed-context/):

> *"Because [Horizon Context] is native to the Snowflake engine, governance framework is enforced at the meaning level, not just the table level. Your role-based access control policies and row-level masking follow the context: every tool, every query and every AI response. A definition restricted for the finance team stays restricted in Power BI, in Salesforce and in any agent that queries it."*

The key claim is that governance is enforced at the engine, not cached or copied to a secondary system. This is Snowflake's competitive argument against third-party semantic layers: when definitions live inside the governance engine, they can't drift out of sync with policies. The same masking and access controls that apply to direct table queries apply to semantic view queries, BI queries, and agent queries.

For customers with enterprise catalogs: Snowflake's Horizon Context announcement includes integration statements from Alation and Collibra, while Alation, Atlan, and Collibra all participate in the Apache Ossie community. Horizon Context is positioned as a complementary metadata destination, not a replacement for enterprise catalog platforms that serve broader discovery, stewardship, and lineage use cases across heterogeneous stacks.

---

## Availability Summary

| Feature | Status | Notes |
|---|---|---|
| Horizon Catalog (base) | **GA** | Always available |
| Semantic Views | **GA** | Foundation of the semantic layer |
| Semantic View Autopilot | **GA** | Uses selected tables plus example SQL; supports Tableau `.twb`, `.twbx`, `.tds`, and `.tdsx` ingestion |
| Power BI ingestion for Semantic View Autopilot | **GA (August 18, 2026)** | Supports `.pbit` and `.pbix`; report-level measures and time-intelligence functions remain limited |
| OpenLineage API | **Public Preview** | Configure Airflow etc. to push lineage to Horizon Catalog |
| Horizon Context metadata connectors (PostgreSQL, SQL Server, Tableau, Power BI, dbt) | **Private Preview** | Request access via Snowflake account team |
| Semantic Studio (AI-assisted semantic view IDE) | **Private Preview** | |
| Advanced Semantics (LOD calculations, composable definitions) | **Private Preview** | |
| Cortex Sense | **Announced for Private Preview (mid-July 2026)** | Confirm current account access; initial announcement described one designated role |
| Cortex Sense — per-role context differentiation | **Roadmap** | Explicitly called out as future in Snowflake's blog |
| Power BI semantic view interop | **Private Preview (soon)** | |
| Excel semantic view interop | **Private Preview (soon)** | |

---

## Competitive Context

**Alation and Collibra:** Both supplied Horizon Context integration statements in Snowflake's Summit 2026 announcement. Atlan participates in the Apache Ossie community, but the cited Horizon Context announcement does not document an Atlan integration. Snowflake is not positioning Horizon Context as a wholesale catalog replacement. Its initial five metadata connectors were announced in private preview, so customers needing broad cross-system coverage should compare current connector availability directly.

**Databricks Genie Ontology:** [Announced at Databricks Data + AI Summit 2026](https://www.databricks.com/blog/introducing-genie-one-genie-ontology-and-genie-agents) (June 16, 2026), approximately two weeks after Snowflake's Summit announcements. Addresses the same problem — a continuously learned context layer for AI agents built from query history, pipelines, and connected applications. Different architectural approach and platform. Customers evaluating both platforms should do a structured comparison; the problem statement is identical, the implementation is platform-specific.

---

## Common Objections and How to Respond

**"We already have Alation/Collibra. Do we need this?"**
Horizon Context is not asking you to replace your enterprise catalog. It is asking whether the semantic context that governs your AI agents should live inside the engine that enforces your access policies, or in a separate system that has to stay in sync. For agent workloads specifically, the native-to-engine argument is worth evaluating.

**"The connectors are in private preview. When is it GA?"**
Snowflake hasn't published a GA date. The metadata connectors were announced in private preview, and Cortex Sense was announced for private preview in mid-July 2026. Confirm current access through the account team rather than implying availability on every account.

**"We built semantic views as security boundaries. Does Sense break that?"**
Data access boundaries (RBAC) and configured-tool privilege checks remain enforced. The open question is whether Sense context retrieval for a configured agent is further scoped to its declared tools. Snowflake has not specified this publicly. Do not promise either behavior; use least-privilege RBAC and raise the retrieval-boundary question with the account team.

**"Select Star was an independent product. Are you killing it?"**
Snowflake announced a definitive agreement to acquire the technology and team. The cited announcement does not establish closing, and no public statement has been made about the Select Star standalone product roadmap. Point to Snowflake's announcement and let the account team address transaction or product-transition questions.

**"Benchmarks don't mean much."**
Agree — the 24% → 86% figure is from Snowflake's internal testing on their own data. The relevant question for any customer is: *what percentage of your data estate is covered by semantic views today?* If the answer is low (Snowflake found theirs was under 5%), then the gap Sense fills is real regardless of the exact benchmark.

---

## Related Guides

- [Snowflake Horizon Catalog](https://docs.snowflake.com/en/user-guide/snowflake-horizon)
- [Cortex Agents access control and authentication](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-setup)
- [Restricted Session Scope for agents](https://docs.snowflake.com/en/user-guide/restricted-session-scope)
- [Best practices for semantic views](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices)

---

## Development Tools

- `AGENTS.md` records project-specific claim and availability rules.
- `.claude/skills/guide-horizon-context-catalog/SKILL.md` defines the maintenance workflow for future connector and status updates.
- `docs/01-WHAT-CAN-I-DO-NOW.md` translates the guide into currently actionable steps and preview-access questions.

---

## External References

- [Horizon Context blog — Snowflake (June 2, 2026)](https://www.snowflake.com/en/blog/horizon-context-governed-context/)
- [Cortex Sense blog — Snowflake (June 30, 2026)](https://www.snowflake.com/en/blog/enterprise-ai-agents-grounded-context/)
- [Snowflake agreement to acquire Select Star — Snowflake blog](https://www.snowflake.com/en/blog/snowflake-acquire-select-star/)
- [Horizon Context product page](https://www.snowflake.com/en/product/features/horizon-context/)
- [Horizon Catalog product page](https://www.snowflake.com/en/product/features/horizon/)
- [Cortex Agents documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Cortex Agents access control and authentication](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-setup)
- [Cortex Agents inaccessible tool handling](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-inaccessible-tool-handling)
- [Restricted Session Scope for agents](https://docs.snowflake.com/en/user-guide/restricted-session-scope)
- [Creating semantic views with Semantic View Autopilot](https://docs.snowflake.com/en/user-guide/views-semantic/creating-with-snowsight)
- [Power BI ingestion for Semantic View Autopilot — GA release note](https://docs.snowflake.com/en/release-notes/2026/other/2026-08-18-semantic-views-power-bi-ingestion-ga)
- [Apache Ossie (Incubating), formerly Open Semantic Interchange](https://www.snowflake.com/en/blog/apache-ossie-open-semantic-interchange-incubator/)
- [P0 Security: Snowflake Cortex agents and privilege inheritance (April 2026)](https://p0.dev/blog/when-your-snowflake-ai-agent-can-query-everything-you-can-query/) — external security research, not a Snowflake statement
