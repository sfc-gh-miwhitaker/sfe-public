# What Can I Do Now?

Pair-programmed by SE Community + Cortex Code

Use this page to choose a capability, then follow its maintained Snowflake documentation. It is a decision guide, not a second copy of connector setup instructions or privilege tables.

> **No support provided.** Reference only; validate before production use.

**October update: 2026-10-13.** Horizon Context connectors are open preview; Semantic Studio is GA. Neither establishes Cortex Sense availability. See the [parent guide](../README.md) for the context stack and security distinctions.

## Start Here

- **Define repeatable business metrics:** use [Semantic Views](https://docs.snowflake.com/en/user-guide/views-semantic/overview) and [Semantic Studio](https://docs.snowflake.com/en/user-guide/views-semantic/semantic-studio), which reached [GA on September 30](https://docs.snowflake.com/en/release-notes/2026/other/2026-09-30-semantic-studio-ga).
- **Reuse BI business logic:** use [Autopilot file ingestion](https://docs.snowflake.com/en/user-guide/views-semantic/autopilot). Importing a model file into a semantic view is different from connecting a BI system's metadata to the catalog.
- **Collect external metadata:** choose a source from the [Horizon Catalog connector catalog](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors). The [October 12 preview release](https://docs.snowflake.com/en/release-notes/2026/other/2026-10-12-horizon-context-preview) defines the hosting-region boundary; do not assume every Snowflake cloud or region is supported.
- **Ingest lineage your tools already emit:** use [external lineage](https://docs.snowflake.com/en/user-guide/external-lineage), a GA path distinct from the preview connectors.
- **Delegate documentation work:** review [metadata access control and APPLY COMMENT](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors/access-control) instead of granting broad modification privileges.
- **Reduce repeated column descriptions:** evaluate [column comment propagation](https://docs.snowflake.com/en/user-guide/comment-propagation). It is opt-in and follows eligible unchanged values, not arbitrary transformations.
- **Evaluate Cortex Sense:** confirm its current availability and retrieval contract separately. Public Horizon Context documentation is not a Sense enablement or security specification.

## Before Connecting a Source

1. **Check source and region eligibility.** Follow the source's page in the [connector catalog](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors), including required permissions and refresh behavior. Source setup is not uniform.
2. **Approve the network and TLS design.** Read [connector security requirements](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors/security). Stable egress IPs are not guaranteed, and TLS enforcement depends on source type. Do not open a database broadly merely to complete setup.
3. **Separate metadata visibility from data access.** Follow [metadata access control](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors/access-control). A role without SELECT can still be allowed to see descriptions and lineage. Test both an intended viewer and a role that must not see the metadata.
4. **Validate a bounded example.** Trace a known source-to-report dependency, inspect descriptions, and confirm who can see and edit the result before expanding collection.

For an OpenLineage producer, use the [external-lineage workflow and limitations](https://docs.snowflake.com/en/user-guide/external-lineage) instead. Do not substitute metadata-connector grants or setup steps for that API's authorization contract.

## Before Enabling Enrichment or Expanding Agent Access

- **Comment propagation:** read its [eligibility, provenance, and disable behavior](https://docs.snowflake.com/en/user-guide/comment-propagation). Turning it off stops future propagation but does not remove existing copies. Review old-object remediation rather than recreating production dependencies casually.
- **Lineage:** check [temporary-object preservation](https://docs.snowflake.com/en/user-guide/lineage-temporary-objects) and [October 6 expanded coverage](https://docs.snowflake.com/en/release-notes/2026/other/2026-10-06-lineage-integrations-monitors-search). A missing historical edge does not prove there is no dependency.
- **Agents:** review [execution identity and tool privileges](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-setup), [inaccessible-tool handling](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-inaccessible-tool-handling), and [Restricted Session Scope](https://docs.snowflake.com/en/user-guide/restricted-session-scope). `reject` checks only the documented tool set, not every execution dependency. Audit owner-rights tools separately.

## Evaluate Cortex Sense Deliberately

The October 13 review found a [CoCo release-note reference to Sense feedback](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/release-notes/v1-21-6), but no dedicated public availability or retrieval-access documentation. Confirm with the account team:

- Supported accounts, regions, clients, and sources.
- Indexing, refresh, consumption, and administration.
- Who can retrieve each context, and whether retrieval for a configured agent is bounded by its declared tools.

Then evaluate representative questions against known-good answers. Measure correctness, refusal behavior, latency, consumption, and retrieved sources. Keep sensitive metadata out until the retrieval boundary is established. Snowflake's published internal benchmark is not a customer forecast.

## Decision Rule

Use semantic views for explicit business definitions, lineage or metadata connectors for cross-system context, and separate grants for metadata visibility and data access. Treat Cortex Sense as a separately qualified runtime capability, not an automatic consequence of connecting the catalog.

## External References

- [Horizon Context](https://docs.snowflake.com/en/user-guide/snowflake-horizon/horizon-context)
- [Horizon Catalog connectors](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors)
- [Metadata access control](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors/access-control)
- [Connector security](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors/security)
- [Column comment propagation](https://docs.snowflake.com/en/user-guide/comment-propagation)
- [External lineage](https://docs.snowflake.com/en/user-guide/external-lineage)
- [Semantic Studio](https://docs.snowflake.com/en/user-guide/views-semantic/semantic-studio)
- [Cortex Sense announcement](https://www.snowflake.com/en/blog/enterprise-ai-agents-grounded-context/)
