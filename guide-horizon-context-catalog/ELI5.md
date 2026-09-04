> Simplified from: guide-horizon-context-catalog/README.md

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Snowflake announced an agreement to acquire a data catalog company's team and technology, then introduced a three-layer stack — inventory (Horizon Catalog), enrichment from outside systems (Horizon Context), and runtime context for CoCo queries (Cortex Sense) — that changes how AI gets the business definitions it needs to answer correctly.

## The Story (analogy-driven)

Imagine a hospital with thousands of patient files. The old filing system (traditional catalogs) was a card index: it told you which drawer to open, but you had to read the file yourself. That worked when humans were the ones looking things up.

Now AI doctors (agents) are answering questions. They don't browse card indexes — they need the right context handed to them at the moment they're asked. So the hospital builds three new layers:

1. **Horizon Catalog** — the filing cabinets themselves. What files exist, who can access them, how they connect. Always existed.
2. **Horizon Context** — a service that pulls records from partner clinics and labs into the same system, stitches them together, and notes which files are most trusted.
3. **Cortex Sense** — when CoCo gets a question, retrieves the relevant context instead of making CoCo inspect every possible file one by one.

The result: accuracy went from 24% to 86% on hard questions in Snowflake's internal testing.

## The Cast (concept glossary)

- **Horizon Catalog** — Snowflake's built-in inventory of your data: tables, views, lineage, access policies.
- **Horizon Context** — The new layer that pulls metadata from systems outside Snowflake (Tableau, Power BI, PostgreSQL, dbt) and enriches it.
- **Cortex Sense** — A managed context layer demonstrated with CoCo that retrieves relevant catalog context at query time. Public sources do not establish that it is automatically injected into every agent or AI request.
- **Select Star** — A catalog company whose team and platform technology Snowflake announced an agreement to acquire for cross-system lineage and popularity signals. The cited announcement does not establish that the transaction closed.
- **Semantic View** — A business-friendly description of your tables that tells AI what each metric means. The highest-authority signal Sense uses.
- **Metadata Connector** — A built-in integration that pulls schemas and definitions from external tools into Horizon Catalog.
- **Apache Ossie (Incubating)** — The open semantic specification formerly called Open Semantic Interchange (OSI), now incubating at the Apache Software Foundation.

## What Changed

- Before: In Snowflake's internal benchmark, a frontier coding agent with direct SQL access and no context layer reached 24.1% accuracy. Other grounded agent designs already existed; this number is not a baseline for every agent.
- After: In Snowflake's internal benchmark, CoCo grounded by Cortex Sense retrieved relevant business context at query time and reached ~86% accuracy. Horizon Context is intended to extend that foundation with definitions from systems outside Snowflake.

## What to Watch Out For

- **The security boundary question:** Snowflake has not publicly clarified whether Cortex Sense retrieval for a configured Cortex Agent is further limited to that agent's declared tools. Agent execution still uses the calling user's default role, and configured tools still require privileges. Use a least-privilege default role, consider Restricted Session Scope as an additional ceiling, and raise the unresolved retrieval question before enabling sensitive workloads.
- **The announced initial model used one designated role.** Per-role context differentiation was described as future work. Confirm current Cortex Sense access and behavior with the Snowflake account team.
- **Most features are early access.** Horizon Context connectors were announced in private preview, and Cortex Sense was announced for private preview in mid-July 2026. Availability is not guaranteed on every account.
- **The benchmark caveat:** The 24% to 86% figure is from Snowflake's internal testing on its own data. It is not a general before-and-after result for every agent or customer workload.

## The One Thing to Remember

The published result shows the value of relevant business context: in Snowflake's internal test, CoCo grounded by Cortex Sense substantially outperformed a direct-SQL frontier agent. Treat that as evidence for the design, not a promised customer outcome.

> For the full technical details, see the source document.
