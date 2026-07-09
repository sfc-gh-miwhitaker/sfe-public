> Simplified from: guide-vscode-copilot-cortex/README.md

## One-Sentence Version

There are three ways to bring Snowflake AI into VS Code — a built-in panel, a routing trick from the Copilot CLI, and a governed MCP server — and they differ mainly in setup time, admin requirements, and where the AI brain lives.

## The Story (analogy-driven)

Imagine VS Code is your office desk. You want a Snowflake expert sitting next to you while you work. Three ways to get one:

- **Path 1 (~2 min, no admin):** The expert already works in your building (the Snowflake extension). Sign in once, click a button, and they pull up a chair. Full CoCo agent — knows Snowflake deeply.
- **Path 2 (~5 min, no admin):** Your existing assistant (Copilot CLI) learns to recognize Snowflake questions and pages the expert when they come up. Non-Snowflake questions stay with your assistant.
- **Path 3 (~30 min, needs admin):** IT sets up a secure intercom (MCP server) between your desk and the expert. Every call is logged and governed under your company's access controls.

## The Cast (concept glossary)

- **CoCo** — Snowflake's coding agent (formerly Cortex Code); the AI that knows your Snowflake data natively.
- **MCP server** — A governed endpoint that exposes Snowflake tools (search, analytics, agents) to Copilot Chat.
- **Semantic view** — A business-level description of your data that makes any path more accurate.
- **Cross-region inference** — A setting that lets you use AI models not natively hosted in your Snowflake region.
- **SYSTEM_EXECUTE_SQL** — An MCP tool that lets the AI run arbitrary SQL; has real cost and accuracy implications.

## What Changed

- Before: connecting VS Code to Snowflake AI meant custom integrations with no standardized approach.
- After: three official paths exist, ranging from two-minute no-admin to thirty-minute fully governed.

## What to Watch Out For

- Path 1 (VS Code extension panel) is in Preview — usable but pre-GA.
- Path 3 requires an Enterprise Copilot license; your GitHub org admin must enable the "MCP servers in Copilot" policy first.
- Pin model names to bare versions (e.g., `claude-sonnet-4-6`). Date-suffixed model IDs are rejected.
- If a model isn't in your region, you need `ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION` — otherwise calls fail silently or error.
- Government regions are not supported for any path.

## The One Thing to Remember

All three paths get more accurate from the same foundation: a semantic view describing your data in business terms. Build that once and every path benefits — you're choosing a surface, not a fundamentally different accuracy story.

> For the full technical details, see the source document.
