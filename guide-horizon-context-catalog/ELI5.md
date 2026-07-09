> Simplified from: guide-horizon-context-catalog/README.md

## One-Sentence Version

Snowflake acquired a data catalog company and built a three-layer stack — inventory (Horizon Catalog), enrichment from outside systems (Horizon Context), and automatic context delivery to AI agents (Cortex Sense) — that fundamentally changes how AI gets the business definitions it needs to answer correctly.

## The Story (analogy-driven)

Imagine a hospital with thousands of patient files. The old filing system (traditional catalogs) was a card index: it told you which drawer to open, but you had to read the file yourself. That worked when humans were the ones looking things up.

Now AI doctors (agents) are answering questions. They don't browse card indexes — they need the right context handed to them at the moment they're asked. So the hospital builds three new layers:

1. **Horizon Catalog** — the filing cabinets themselves. What files exist, who can access them, how they connect. Always existed.
2. **Horizon Context** — a service that pulls records from partner clinics and labs into the same system, stitches them together, and notes which files are most trusted.
3. **Cortex Sense** — when an AI doctor gets a question, automatically hands them only the relevant files, without anyone having to say which ones to grab.

The result: accuracy went from 24% to 86% on hard questions in Snowflake's internal testing.

## The Cast (concept glossary)

- **Horizon Catalog** — Snowflake's built-in inventory of your data: tables, views, lineage, access policies.
- **Horizon Context** — The new layer that pulls metadata from systems outside Snowflake (Tableau, Power BI, PostgreSQL, dbt) and enriches it.
- **Cortex Sense** — The runtime layer that automatically retrieves and delivers relevant catalog context to each AI query, without manual configuration.
- **Select Star** — A catalog company Snowflake acquired for its cross-system lineage and popularity signals.
- **Semantic View** — A business-friendly description of your tables that tells AI what each metric means. The highest-authority signal Sense uses.
- **Metadata Connector** — A built-in integration that pulls schemas and definitions from external tools into Horizon Catalog.

## What Changed

- Before: AI agents either had to be manually configured with exact table references, or they guessed blind (24% accuracy). Catalog data was a passive inventory for humans to browse.
- After: Cortex Sense automatically delivers relevant business context to AI agents at query time. Horizon Context extends that context to include definitions from systems outside Snowflake. Accuracy reaches ~86% without manual agent configuration per query.

## What to Watch Out For

- **The security boundary question:** Cortex Sense retrieves context based on the calling role's full scope — not necessarily limited to the specific semantic view an agent was configured with. The agent still can't *query* data beyond its tools, but it may *know* things exist beyond them. Snowflake has not publicly clarified whether Sense respects agent tool boundaries. Raise this with your account team before enabling on sensitive workloads.
- **Single-role access only in private preview.** Per-role context differentiation (marketing sees marketing context, finance sees finance context) is on the roadmap but not available yet.
- **Most features are in private preview.** Horizon Context connectors and Cortex Sense are early access. Availability is expanding but not guaranteed on every account today.
- **The benchmark caveat:** The 24% to 86% figure is from Snowflake's internal testing on their own data. Your results will vary based on how much of your data estate has semantic views.

## The One Thing to Remember

The gap between a 24%-accurate AI agent and an 86%-accurate one is not a better model — it's whether the agent gets governed business definitions automatically at query time, and that's what this stack delivers.

> For the full technical details, see the source document.
