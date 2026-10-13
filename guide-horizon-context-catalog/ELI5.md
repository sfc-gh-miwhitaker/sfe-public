> Simplified from: guide-horizon-context-catalog/README.md

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Snowflake brings data descriptions together, but permission to read those descriptions is different from permission to read the data itself.

## The Story (analogy-driven)

Imagine a library whose books are scattered across several buildings. Its catalog tells you what exists, what each book covers, and which books people trust.

Horizon Context adds descriptions from other libraries to that catalog. It also helps people maintain definitions and follow connections between sources. The connectors bring metadata, meaning information about data, rather than copying the underlying business records.

Cortex Sense is the separately announced service demonstrated finding relevant context for CoCo, Snowflake's coding assistant. Connecting the catalog does not establish that Sense is available or active.

A catalog card and a book have different access rules. Someone might be allowed to read the card but not borrow the book. If the title itself is confidential, locking away the book is not enough.

## The Cast (concept glossary)

- **Horizon Catalog** — The inventory of data assets and their descriptions, relationships, and governance information.
- **Horizon Context** — The capabilities that collect, enrich, and deliver that information to people and tools.
- **Metadata connector** — A connection that brings descriptions and relationships from an external system into the catalog.
- **Semantic View** — An explicit definition of business metrics and how to calculate them.
- **Cortex Sense** — The announced runtime service demonstrated selecting relevant business context for CoCo questions.

## What Changed

- The [October 12 Horizon Context preview](https://docs.snowflake.com/en/release-notes/2026/other/2026-10-12-horizon-context-preview) introduced 18 documented connectors; they are no longer just an announcement.
- Stewards can edit descriptions without receiving broad modification permissions.
- Optional description propagation reduces repeated writing where downstream columns keep the same values.
- [Semantic Studio](https://docs.snowflake.com/en/release-notes/2026/other/2026-09-30-semantic-studio-ga), the semantic-view authoring environment, became generally available on September 30.

## What to Watch Out For

- **Catalog access and data access are separate.** Review who can see names and descriptions, not only who can query rows.
- **Preview access still has limits.** Follow the [connector catalog](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors) for current sources, setup instructions, and region requirements.
- **A connection needs a security review.** Read the [network and encryption requirements](https://docs.snowflake.com/en/user-guide/snowflake-horizon/connectors/security) before exposing a source. Stable outbound addresses are not guaranteed.
- **An agent's tool list is not a universal security fence.** Different tools have different permissions; some programs run with their owner's authority.
- **Sense's retrieval boundary remains unverified publicly.** The October 13 review found no dedicated public contract explaining whether an agent's declared tools also restrict Sense retrieval.
- **Horizon Context preview does not establish Sense availability.** Confirm Sense access and behavior before introducing sensitive metadata.
- **Benchmarks are not promises.** Snowflake reported roughly 24% versus 86% accuracy in an internal comparison. That does not predict a customer's results.

## The One Thing to Remember

Better descriptions help AI choose the right data, but descriptions need their own access controls too.

> For the full technical details, see the source document.
