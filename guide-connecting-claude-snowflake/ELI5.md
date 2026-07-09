> Simplified from: guide-connecting-claude-snowflake/README.md

## One-Sentence Version

There are several ways to put Claude (the AI) in front of your Snowflake data — this guide helps you pick the right one by asking "who is the user?" instead of "which protocol?"

## The Story (analogy-driven)

Imagine your company's data lives in a bank vault. You want an AI assistant to answer questions about what's inside — but you don't want to hand over the vault keys and hope for the best.

Option A: the bank hires its own staff member who already has security clearance and knows the vault layout (CoWork/CoCo — AI that runs inside Snowflake). Option B: an outside consultant gets a carefully scoped visitor badge that only works at specific desks (Governed MCP). Option C: you photocopy selected pages and slide them under the door (legacy MCP with no grounding).

Option A answers about 86% of hard questions correctly. Option C answers about 24%. The difference is whether the AI has governed business context or is guessing blind.

All three options benefit from the same prep work: writing down what your data means in business terms (a "semantic view") and saving a few example questions with correct answers. Do that once and every option gets smarter.

## The Cast (concept glossary)

- **CoWork** — Snowflake's chat assistant for business users; coordinates AI agents behind the scenes.
- **CoCo** — Snowflake's coding agent for developers; like Claude Code but it already knows your Snowflake.
- **Cortex Sense** — The service that feeds business definitions to an AI at the moment it answers a question.
- **Horizon Context** — Where your governed business definitions live inside Snowflake.
- **Natoma MCP gateway** — One governed front door for external AI tools to call Snowflake, instead of wiring credentials per app.
- **Semantic view** — A business-friendly description of your tables that tells the AI what each column actually means.

## What Changed

- Before: connecting Claude to Snowflake meant hand-rolling OAuth, writing a custom MCP server, and accepting ~24% accuracy on hard questions.
- After: Claude models run inside Snowflake (no data leaves). CoCo and CoWork are native surfaces. A governed gateway (Natoma) replaces per-app OAuth plumbing. Accuracy jumps to ~86% with Cortex Sense context.

## What to Watch Out For

- The legacy "raw MCP tunnel" pattern (no grounding, no semantic view) gets roughly one in four hard questions right and costs more tokens. It's the worst option unless you have no alternative.
- CoCo Desktop is in public preview — usable today, but pre-GA and may change.
- The `cortex mcp serve` delegate path requires the `cortex` CLI installed locally. If a customer can't install it, fall back to the native MCP connector pattern.

## The One Thing to Remember

Pick the surface by who the user is (business user = CoWork, developer = CoCo, external agent = governed MCP) — the accuracy homework is the same for all of them.

> For the full technical details, see the source document.
