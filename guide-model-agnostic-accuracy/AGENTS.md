# Model-Agnostic Accuracy Guide — Project Instructions

Pair-programmed by SE Community + Cortex Code

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Primary guide (README.md) with 5 sections covering semantic view configuration,
agent configuration, evaluation, model selection strategy, and iteration practices,
plus governed-source trust guidance and an ELI5.md companion.
No SQL scripts, no demo infrastructure, no Streamlit.

## Snowflake Environment

No account connection or deployment is required to read this guide. Its examples
are configuration guidance, not an executable Agent specification.

## Conventions

- All claims must link to either official Snowflake docs or a Snowflake Builders Blog post
- Practitioner quotes use blockquote format with attribution
- Each section has "Why this matters" framing before practices
- Tables used for practice summaries; prose used for reasoning
- No code samples longer than 10 lines (this is a practices guide, not a tutorial)
- Public trust guidance distinguishes the Preview `SNOWFLAKE.TAGS.CERTIFICATION_STATUS`
  tag from the still-supported legacy tag
- README metadata is the single source for the guide's review baseline and expiry

## Key Commands

Run from the repository root:

```bash
python3 .github/scripts/expire-projects.py --check
python3 .github/scripts/check-public-content.py
npm --prefix site test
```

For rendered-link checks, build the reader site first using `site/README.md`, then
run `npm --prefix site run check`. These checks validate presentation and metadata;
technical changes also require the feature-specific documentation checks below.

## Review Focus

Review semantic-view modeling guidance, Agent model availability, evaluation
versions, and announced judge retirements against current documentation. Keep
Analyst diagnostics distinct from end-to-end Agent release gates.
