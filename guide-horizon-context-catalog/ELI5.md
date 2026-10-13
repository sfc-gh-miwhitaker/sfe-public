> Simplified from: guide-horizon-context-catalog/README.md

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Snowflake brings data descriptions together, but permission to read those descriptions is different from permission to read the data itself.

## The Library Analogy

Imagine a library whose books are scattered across several buildings. Its catalog tells you what exists, what each book covers, and which books people trust.

Horizon Context adds descriptions from other libraries to that catalog. It also helps people maintain definitions and follow connections between sources. The connectors bring metadata, meaning information about data, rather than copying the underlying business records.

Cortex Sense is the separately announced service demonstrated finding relevant context for CoCo, Snowflake's coding assistant. Confirm its availability for your account separately from your catalog connections.

A catalog card and a book have different access rules. Someone might be allowed to read the card but not borrow the book. If the title itself is confidential, locking away the book is not enough.

## Key Terms

- **Horizon Catalog** — The inventory of data assets and their descriptions, relationships, and governance information.
- **Horizon Context** — The capabilities that collect, enrich, and deliver that information to people and tools.
- **Metadata connector** — A connection that brings descriptions and relationships from an external system into the catalog.
- **Semantic View** — An explicit definition of business metrics and how to calculate them.
- **Cortex Sense** — The announced runtime service demonstrated selecting relevant business context for CoCo questions.

## What Changed

- The [October 12 Horizon Context preview](https://docs.snowflake.com/en/release-notes/2026/other/2026-10-12-horizon-context-preview) introduced 18 metadata connectors for BI tools, databases, and dbt.
- Stewards can edit descriptions without receiving broad modification permissions. They can also maintain descriptions, tags, and contacts for external dashboards within Horizon Catalog.
- Optional description propagation reduces repeated writing where downstream columns keep the same values.
- [Semantic Studio](https://docs.snowflake.com/en/release-notes/2026/other/2026-09-30-semantic-studio-ga), the semantic-view authoring environment, became generally available on September 30.

## What to Watch Out For

- **Catalog access and data access are separate.** Review who can see names and descriptions, not only who can query rows.
- **Preview access still has limits.** Follow the [connector catalog](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors) for current sources, setup instructions, and region requirements.
- **A connection needs a security review.** Read the [network and encryption requirements](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors/security) before exposing a source. Stable outbound addresses are not guaranteed.
- **An agent's tool list is not a universal security fence.** Different tools have different permissions; some programs run with their owner's authority.
- **Confirm Sense access before an evaluation.** Ask your Snowflake account team which clients are supported and which metadata each role can retrieve. Filtering Sense retrieval by an agent's tool list remains unconfirmed; keep sensitive metadata out until you have validated that boundary.
- **Benchmarks are not promises.** Snowflake reported roughly 24% versus 86% accuracy in an internal comparison. Test your own questions to see how well it works for you.

## The One Thing to Remember

Better descriptions help AI choose the right data, but descriptions need their own access controls too.

> For architecture, access controls, and setup links, see the [full guide](README.md).
