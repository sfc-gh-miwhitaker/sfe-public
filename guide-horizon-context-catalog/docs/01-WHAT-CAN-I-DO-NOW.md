# What Can I Do Now?

Pair-programmed by SE Community + Cortex Code

This page turns the Horizon Context and Cortex Sense announcements into actions you can take with currently documented capabilities. It separates work you can start directly from preview features that require confirmation or account-team access.

> **No support provided.** Reference only; validate before production use.

## Start Here

Choose the outcome you need:

| Goal | Start now | Availability boundary |
|---|---|---|
| Improve natural-language analytics accuracy | Build or refine native Semantic Views | Semantic Views and Semantic View Autopilot are GA |
| Reuse existing BI business logic | Ingest supported Tableau or Power BI files with Semantic View Autopilot | Power BI ingestion became GA on August 18, 2026 |
| Make Cortex Agents safer to operate | Tighten the querying user's default role, require declared tools when appropriate, and apply Restricted Session Scope | Verify RSS support for the client and execution path you use |
| Extend lineage into Horizon Catalog | Send lineage from an OpenLineage producer such as Apache Airflow | OpenLineage API was announced in Public Preview |
| Pull metadata from external databases and BI tools | Request Horizon Context metadata connector access | The first five connectors were announced in Private Preview |
| Evaluate Cortex Sense | Ask the Snowflake account team to confirm current access and behavior | Announced for Private Preview in mid-July 2026 |

## 1. Strengthen Semantic Views

Semantic Views remain the authoritative source for governed, repeatable business definitions. Start here when the questions and metrics are known.

1. Pick one business domain and an initial set of fewer than 10 tables or views.
2. Define clear descriptions, relationships, metrics, and reusable filters.
3. Add verified queries for common questions and known edge cases.
4. Create an evaluation set and measure SQL correctness before broad rollout.
5. Review user feedback and add verified queries or model refinements as usage grows.

Use Cortex Search for literal matching when users refer to high-cardinality values such as customer or product names. Do not use verified queries to compensate for missing relationships or weak business definitions.

## 2. Import Existing BI Logic

Semantic View Autopilot can reuse models your organization already maintains instead of rebuilding every definition manually.

| Source | Supported input | Important limits |
|---|---|---|
| Tableau | `.twb`, `.twbx`, `.tds`, `.tdsx` | Snowflake connections only; LOD calculations and Tableau virtual connections are not supported |
| Power BI | `.pbit`, `.pbix` | Report-level measures and time-intelligence functions are not yet fully supported |
| SQL | Question-and-query pairs in the UI or a two-column CSV | Queries are validated; accepted examples can become verified queries |

After import, review generated relationships, metrics, descriptions, and verified queries. Treat the generated view as a starting point that still needs domain-owner validation.

## 3. Put Explicit Controls Around Cortex Agents

Do not use Cortex Sense or tool configuration as a substitute for least-privilege execution controls.

1. Give each user who calls the agent a purpose-built default role with only the required object privileges.
2. Grant that default role access to the agent, its warehouse, and each configured tool and underlying resource.
3. Set `orchestration.tool_not_accessible: reject` when a run must not begin unless every named Cortex Analyst, Cortex Search, MCP, or skill tool is accessible.
4. Use the default `accept` mode only when degraded operation with accessible tools is intentional and the client surfaces warnings.
5. Apply Restricted Session Scope when agent-active sessions need a privilege ceiling below the user's RBAC grants.
6. Review Agent observability events for inaccessible-tool warnings and unexpected execution paths.

Explicit Cortex Analyst and Cortex Search resources narrow those tools. They are not a universal sandbox: SQL execution, code execution, functions, and generic tools follow their own definitions and the default role's privileges. Restricted Session Scope intersects with RBAC and can constrain agent activity, but it does not document or determine Cortex Sense's retrieval boundary.

## 4. Extend Lineage With OpenLineage

If Apache Airflow or another OpenLineage-compatible system already emits lineage events, evaluate sending those events to Horizon Catalog.

Before rollout:

- Confirm that the OpenLineage API is available in the target account and region.
- Start with a bounded pipeline or domain.
- Verify that external and Snowflake-native column lineage stitches together as expected.
- Define ownership for failed events, schema changes, and stale lineage.
- Keep the Public Preview status visible in production-readiness reviews.

## 5. Request Horizon Context Connector Access

The first metadata connectors announced for Horizon Context cover PostgreSQL, Microsoft SQL Server, Tableau, Power BI, and dbt. They were announced in Private Preview.

Prepare the following before requesting access:

- The systems and environments to connect.
- The metadata required: schemas, query logs, dashboard definitions, measures, or model lineage.
- The service identity and least-privilege access available in each source.
- Data residency, network, and metadata-governance requirements.
- A small validation scope with expected lineage and business definitions.
- Success criteria for discovery quality, lineage coverage, and semantic reuse.

Do not represent connector access, supported versions, or regional coverage as guaranteed until the account team confirms them for the target account.

## 6. Evaluate Cortex Sense Deliberately

Cortex Sense was announced for Private Preview in mid-July 2026. Public material demonstrates CoCo grounded by Cortex Sense, but it does not establish transparent injection into every Cortex Agent or third-party agent.

Ask the account team to confirm:

- Whether Cortex Sense is enabled for the target account and region.
- Which CoCo surfaces and data sources are supported.
- How initial indexing, refresh cadence, and ongoing consumption are measured.
- Which role receives access and whether per-role contexts are available.
- Whether retrieval for a configured Cortex Agent is bounded by that agent's declared tools or by another scope.
- How conflicts, corrections, evaluations, and deletion are administered.

Run an evaluation with representative business questions and a known-good answer set. Track SQL correctness, refusal behavior, latency, cost, and the sources used. Treat Snowflake's published 24.1% to 86.3% accuracy and $1.76 to $0.59 per-query results as internal benchmark evidence, not a customer forecast.

## 30-Day Action Plan

| Window | Action | Evidence of completion |
|---|---|---|
| Week 1 | Inventory agent default roles, declared tools, semantic views, and existing BI models | Named owner and current-state inventory |
| Week 2 | Improve one Semantic View or import one supported BI model | Reviewed definitions plus an initial evaluation set |
| Week 3 | Tighten Agent execution controls and test inaccessible-tool behavior | Least-privilege grants, selected mode, and captured warnings or rejection |
| Week 4 | Evaluate one preview path only if it closes a documented gap | Account-team confirmation, bounded scope, success criteria, and rollback decision |

## Decision Rule

- Use a **Semantic View** when the business definition must be explicit, repeatable, and auditable.
- Use **OpenLineage or a metadata connector** when the missing input is cross-system context.
- Evaluate **Cortex Sense** when CoCo must answer across data that is not fully modeled, and accept that its current access and retrieval behavior require confirmation.
- Use **least-privilege RBAC and Restricted Session Scope** to control execution. Do not treat context retrieval as a security boundary.

## External References

- [Snowflake Horizon Catalog](https://docs.snowflake.com/en/user-guide/snowflake-horizon)
- [Creating semantic views with Semantic View Autopilot](https://docs.snowflake.com/en/user-guide/views-semantic/creating-with-snowsight)
- [Best practices for semantic views](https://docs.snowflake.com/en/user-guide/views-semantic/best-practices)
- [Power BI ingestion for Semantic View Autopilot — GA release note](https://docs.snowflake.com/en/release-notes/2026/other/2026-08-18-semantic-views-power-bi-ingestion-ga)
- [Cortex Agents access control and authentication](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-setup)
- [Cortex Agents inaccessible tool handling](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-inaccessible-tool-handling)
- [Restricted Session Scope for agents](https://docs.snowflake.com/en/user-guide/restricted-session-scope)
- [Horizon Context announcement](https://www.snowflake.com/en/blog/horizon-context-governed-context/)
- [Cortex Sense announcement](https://www.snowflake.com/en/blog/enterprise-ai-agents-grounded-context/)
