# Horizon Context Catalog Guide — Project Instructions

Pair-programmed by SE Community + Cortex Code

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

This is a documentation-only guide. No Snowflake objects are deployed.

Files:

- `README.md` — the full guide (main deliverable)
- `ELI5.md` — analogy-driven summary synchronized with the README's factual guardrails
- `docs/01-WHAT-CAN-I-DO-NOW.md` — actionable checklist for GA capabilities and preview evaluation
- `AGENTS.md` — this file
- `.claude/skills/guide-horizon-context-catalog/SKILL.md` — maintenance workflow and claim guardrails

## Conventions

- All factual claims must trace to a public Snowflake source (blog post, docs page, or clearly attributed third-party)
- Claims about product availability must include the exact status word Snowflake uses (GA / Public Preview / Private Preview) **and** the dated release note or documentation page that establishes it. Where no such source exists, the status must read "unconfirmed — verify with your account team" rather than asserting a maturity level.
- Benchmark figures must carry the internal-test label from the source blog
- Check Cortex Sense availability independently from Horizon Context. Use dated public evidence, not a permanent maturity assumption or an absolute claim that no documentation exists
- The Cortex Sense tool-scope retrieval question must be re-verified, not merely restated, on every revision, and carry the date it was last checked
- Use "CoWork" in prose for the interface formerly called Snowflake Intelligence; keep `SNOWFLAKE_INTELLIGENCE` unchanged in any DDL
- This guide does not carry competitive positioning, vendor comparisons, or objection-handling content
- No pricing claims for Cortex Sense beyond documented indexing and per-query cost discussion
- Keep this guide a decision aid: link to official connector inventories, setup steps, privilege tables, and limitations rather than copying them. Retain only distinctions and risk gates needed to choose safely
- Treat metadata visibility, metadata editing, data access, and delegated tool authority as separate controls. Neither removing SELECT nor narrowing configured tools proves metadata is hidden
- Date targeted feature updates separately; narrow corrections do not reset the full-guide verification or expiry clock

## Key Commands

No deploy script. Guide is markdown-only.
To update: edit `README.md` directly. Re-run `applyrules` before committing.
