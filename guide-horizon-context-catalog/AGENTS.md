# Horizon Context Catalog Guide — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

This is a documentation-only guide. No Snowflake objects are deployed.

Files:
- `README.md` — the full guide (main deliverable)
- `AGENTS.md` — this file

## Conventions

- All factual claims must trace to a public Snowflake source (blog post, docs page, or clearly attributed third-party)
- Claims about product availability must include the exact status word Snowflake uses: GA / Public Preview / Private Preview
- Benchmark figures must carry the internal-test label from the source blog
- No claims about Select Star standalone product roadmap (unconfirmed)
- No pricing claims for Cortex Sense beyond documented indexing and per-query cost discussion

## Key Commands

No deploy script. Guide is markdown-only.
To update: edit `README.md` directly. Re-run `applyrules` before committing.
