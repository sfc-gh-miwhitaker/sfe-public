> Simplified from: demo-media-campaign-analytics/README.md

## One-Sentence Version

Paste one file into Snowflake, wait 5 minutes, and your team can ask plain-English questions about ad campaign performance — no dashboards to build, no SQL to write.

## The Story (analogy-driven)

Imagine you hired a junior analyst who already knows your data model, never takes a day off, and answers in under 3 seconds. That's what this demo puts in front of a customer in a single meeting.

You open a chat window in Snowflake, type "Which channel has the best ROAS this year?" and get back a number, a chart, and context. Then you ask "What was the creative strategy for that client's social campaigns?" and get back the brief — the actual document, summarized and cited. Same chat, same agent, structured data and unstructured documents together.

The demo exists to create a reaction: *"Wait — it searches our documents AND our databases? In one question?"* That reaction is the point. Everything else (the schema, the semantic view, the search service, the agent spec) is scaffolding that makes the reaction happen reliably in a live setting.

## The Cast (concept glossary)

- **Cortex Agent** — The chatbot. It takes a question, decides whether to query structured data or search documents (or both), and returns the answer in plain English plus an optional chart.
- **Semantic View** — The reason the chatbot writes *correct* SQL over structured data. It's a metadata layer that defines what "ROAS" means, what "this year" means, and which columns map to which business concepts.
- **Cortex Search Service** — The reason the chatbot finds the right *documents*. It indexes campaign briefs, creative copy, strategy notes, and client context so the agent can search them by meaning, not just keywords.
- **Snowflake Intelligence** — The chat UI where the agent lives. No code to write; it's built into Snowsight.
- **Verified Queries** — Pre-tested question/answer pairs. They serve as starter prompts in the UI so the audience doesn't stare at a blank chat box.

## What This Demo Proves to a Customer

- Natural language → accurate answers over *their kind of data* (media/advertising KPIs)
- Structured data AND unstructured documents in the same agent — no switching tools
- No external tools, no Python, no API keys — everything runs inside Snowflake's perimeter
- Deploy in one paste — the total cost of "trying it" is 5 minutes and an X-Small warehouse
- Governed by default — same RBAC, same audit trail, same security boundary as their existing Snowflake data

## What to Watch Out For

- This is synthetic data. The point is the *interaction pattern*, not the numbers. Don't let the audience fixate on whether the ROAS values are realistic.
- Connected TV shows NULL for click metrics. That's intentional (impression-only channel) — demo it as a feature ("the agent knows CTV doesn't have clicks") not a bug.
- If the audience asks "can it handle *our* data?" — the answer is yes, and the path is: point a semantic view at their tables, define their metrics, done. Same architecture, different data.

## The One Thing to Remember

This demo sells the *experience*, not the architecture. The customer should walk away thinking "I want that for my team" — not "I understand how semantic views work." The technical depth comes later, after interest is established.

> For the full technical details, see the source document.
