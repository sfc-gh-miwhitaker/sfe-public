> Simplified from: demo-media-campaign-analytics/README.md

## One-Sentence Version

This demo creates a chatbot that answers plain-English questions about advertising campaign performance — no dashboards, no SQL required from the end user.

## The Story (analogy-driven)

Imagine you run an ad agency. Every morning, your team opens a dozen spreadsheets to answer the same questions: "How much did we spend on social this month?" "Which client is getting the best return?" "Are any campaigns blowing past their budget?"

Instead of those spreadsheets, you install a smart assistant that already understands your data model — channels, clients, campaigns, daily metrics. Anyone on the team can just type a question and get the answer with a chart. No training, no SQL knowledge, no waiting for an analyst to pull a report.

That's what this demo builds: one SQL file creates the fake data (20 clients, 5 ad channels, 18 months of daily performance), teaches Snowflake what the metrics mean (ROAS, CTR, budget pacing), and wires up a chatbot that speaks those metrics fluently.

## The Cast (concept glossary)

- **Semantic View** — A metadata layer that tells the AI what your columns mean, how to compute ratios, and what questions are valid. It's the "dictionary" the chatbot studies before answering.
- **Cortex Agent** — The chatbot itself. It takes a natural language question, uses the semantic view to write correct SQL, runs it, and returns the answer.
- **Snowflake Intelligence** — The UI where the chatbot lives (AI & ML → Agents in Snowsight).
- **Verified Queries** — Pre-approved question/answer pairs baked into the semantic view. They serve as training examples and starter prompts.
- **ROAS** — Return on Ad Spend. Revenue ÷ Spend. The metric every media buyer cares about most.
- **Connected TV** — An impression-only channel (no clicks). The demo handles this edge case so the chatbot doesn't show broken click rates for TV.

## What Changed

- Before: Analysts write SQL or build dashboards. Each new question needs a new chart or a new query. Non-technical stakeholders wait.
- After: Anyone with access types a question, gets an answer in seconds. New questions don't require new development.

## What to Watch Out For

- This is synthetic data. Numbers change on every deploy because they're randomly generated. Don't hardcode expected values.
- The demo uses a shared database (`SNOWFLAKE_EXAMPLE`). Multiple demos can coexist, but `CREATE OR REPLACE SCHEMA` will wipe a previous deploy of this specific demo.
- Connected TV has zero clicks by design. If the chatbot returns NULL for CTR on CTV, that's correct, not broken.
- The semantic view lives in a shared schema (`SEMANTIC_MODELS`), separate from the project schema. Teardown handles both.

## The One Thing to Remember

The magic is in the semantic view, not the agent. The agent is just a thin wrapper that points at the semantic view. If the answers are wrong, fix the semantic view's metric definitions and synonyms — not the agent spec.

> For the full technical details, see the source document.
