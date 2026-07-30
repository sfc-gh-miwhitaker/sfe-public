# Model-Agnostic Accuracy Guide — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Single-file guide (README.md) with 5 sections covering semantic view configuration,
agent configuration, evaluation, model selection strategy, and iteration practices.
No SQL scripts, no demo infrastructure, no Streamlit.

## Conventions

- All claims must link to either official Snowflake docs or a Snowflake Builders Blog post
- Practitioner quotes use blockquote format with attribution
- Each section has "Why this matters" framing before practices
- Tables used for practice summaries; prose used for reasoning
- No code samples longer than 10 lines (this is a practices guide, not a tutorial)

## Key Commands

```bash
# Verify links are not broken (requires network)
grep -oP 'https?://[^\s\)]+' README.md | sort -u

# Check line count (guide should be readable in one sitting)
wc -l README.md  # target: 400-600 lines
```

## Expiration

This guide expires 2026-08-28. Review for accuracy against current docs before that date.
