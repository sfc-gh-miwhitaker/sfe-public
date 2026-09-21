# What Can I Do Now?

Pair-programmed by SE Community + Cortex Code

This page turns the Horizon Context and Cortex Sense announcements into actions you can take with currently documented capabilities. It separates work you can start directly from preview features that require confirmation or account-team access.

> **No support provided.** Reference only; validate before production use.

**Prerequisite:** this page assumes you already know how to build a good semantic view — scoping, descriptions, relationships, metrics, reusable filters, verified queries, and Cortex Search for high-cardinality literal matching. That modeling work is out of scope here.

## Start Here

Choose the outcome you need:

| Goal | Start now | Availability boundary |
| --- | --- | --- |
| Improve natural-language analytics accuracy | Build or refine native Semantic Views | Semantic Views and Semantic View Autopilot are GA |
| Reuse existing BI business logic | Ingest supported Tableau or Power BI files with Semantic View Autopilot | Power BI ingestion became GA on August 18, 2026 |
| Author and debug semantic views conversationally | Use Semantic Studio in Workspaces | Public Preview since August 26, 2026; available to all accounts |
| Make Cortex Agents safer to operate | Tighten the querying user's default role, require declared tools when appropriate, and apply Restricted Session Scope | See the parent guide's agent security-boundary section |
| Extend lineage into Horizon Catalog | Send OpenLineage events from dbt, Apache Airflow, or your own producer | External lineage is GA as of September 3, 2026; requires Enterprise Edition |
| Pull metadata from external databases and BI tools | Request Horizon Context metadata connector access | Announced private preview; no documentation page — confirm per account |
| Evaluate Cortex Sense | Ask the Snowflake account team to confirm current access and behavior | Maturity unconfirmed; no GA release note or documentation page |

## 1. Extend Lineage With OpenLineage

This is the Collect-phase path that is GA today. If Apache Airflow, dbt, or another OpenLineage-compatible system already emits lineage events, you can send them to Horizon Catalog now.

Before rollout:

- Confirm the account is Enterprise Edition or higher, and grant `INGEST LINEAGE` on the account to the sending role (plus `DELETE LINEAGE` if you need to remove edges).
- Make that role the sending user's **default role**. Snowflake resolves payload objects using the default role, not another granted role, and it must be able to resolve every Snowflake object your events name — one unresolvable object rejects the entire event with HTTP 400 and error 394919.
- If your pipeline recreates the tables it reports lineage for, use schema-level `GRANT SELECT ON FUTURE TABLES` or `COPY GRANTS` on `CREATE OR REPLACE TABLE`, or the role loses access on each replace.
- Start with a bounded pipeline or domain and verify that external and Snowflake-native column lineage stitch together as expected.
- Budget against the 20,000-edge-per-account cap and the one-year event retention period.
- Expect HTTP 400 for `START` and `FAIL` events; Snowflake accepts only `COMPLETE`. That is normal for tools emitting a full event lifecycle.

## 2. Request Horizon Context Connector Access

The first metadata connectors announced for Horizon Context cover PostgreSQL, Microsoft SQL Server, Tableau, Power BI, and dbt. They were announced in private preview and have no documentation page.

Prepare the following before requesting access:

- The systems and environments to connect, and the metadata required from each: schemas, query logs, dashboard definitions, measures, or model lineage.
- The service identity and least-privilege access available in each source.
- Data residency, network, and metadata-governance requirements.
- A small validation scope with expected lineage and business definitions, plus success criteria for discovery quality, lineage coverage, and semantic reuse.

Do not represent connector access, supported versions, or regional coverage as guaranteed until the account team confirms them for the target account.

## 3. Evaluate Cortex Sense Deliberately

Public material demonstrates CoCo grounded by Cortex Sense. It does not establish transparent injection into every Cortex Agent or third-party agent, and there is no product documentation page or GA release note.

Ask the account team to confirm:

- Whether Cortex Sense is enabled for the target account and region, and which CoCo surfaces and data sources are supported.
- How initial indexing, refresh cadence, and ongoing consumption are measured.
- Which role receives access and whether per-role contexts are available.
- **Whether retrieval for a configured Cortex Agent is bounded by that agent's declared tools or by the calling user's full role scope.** Get this in writing for your account and release; it is still unanswered publicly.
- How conflicts, corrections, evaluations, and deletion are administered.

Run an evaluation with representative business questions and a known-good answer set. Track SQL correctness, refusal behavior, latency, cost, and the sources used. Treat Snowflake's published 24.1% to 86.3% accuracy and $1.76 to $0.59 per-query results as internal benchmark evidence, not a customer forecast.

## 30-Day Action Plan

| Window | Action | Evidence of completion |
| --- | --- | --- |
| Week 1 | Inventory agent default roles, declared tools, semantic views, and existing BI models | Named owner and current-state inventory |
| Week 2 | Improve one Semantic View or import one supported BI model | Reviewed definitions plus an initial evaluation set |
| Week 3 | Tighten Agent execution controls and test inaccessible-tool behavior | Least-privilege grants, selected mode, and captured warnings or rejection |
| Week 4 | Evaluate one preview path only if it closes a documented gap | Account-team confirmation, bounded scope, success criteria, and rollback decision |

## Decision Rule

- Use a **Semantic View** when the business definition must be explicit, repeatable, and auditable.
- Use **external lineage or a metadata connector** when the missing input is cross-system context.
- Evaluate **Cortex Sense** when CoCo must answer across data that is not fully modeled, and accept that its access and retrieval behavior require confirmation.
- Use **least-privilege RBAC and Restricted Session Scope** to control execution. Do not treat context retrieval as a security boundary.

## External References

- [Snowflake Horizon Catalog](https://docs.snowflake.com/en/user-guide/snowflake-horizon)
- [Semantic View Autopilot](https://docs.snowflake.com/en/user-guide/views-semantic/autopilot)
- [Semantic Studio](https://docs.snowflake.com/en/user-guide/views-semantic/semantic-studio)
- [External lineage](https://docs.snowflake.com/en/user-guide/external-lineage)
- [Cortex Agents access control and authentication](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-setup)
- [Restricted Session Scope for agents](https://docs.snowflake.com/en/user-guide/restricted-session-scope)
- [Horizon Context announcement](https://www.snowflake.com/en/blog/horizon-context-governed-context/)
- [Cortex Sense announcement](https://www.snowflake.com/en/blog/enterprise-ai-agents-grounded-context/)
