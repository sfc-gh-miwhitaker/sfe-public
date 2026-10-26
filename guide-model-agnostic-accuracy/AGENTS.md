# Model-Agnostic Accuracy Guide — Project Instructions

Pair-programmed by SE Community + Cortex Code

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Primary guide (README.md) with 5 sections covering semantic view configuration,
agent configuration, evaluation, model selection strategy, and iteration practices,
plus governed-source trust guidance, an ELI5.md companion, and WORKED-EXAMPLE.md.
The worked example contains a synthetic sales fixture, complete semantic-view and
Agent YAML, and acceptance cases. No deployment scripts or demo infrastructure.

## Snowflake Environment

No account connection or deployment is required to read this guide. The worked
example's specifications require the documented base objects and privileges to use
in Snowflake; the guide does not provision them or launch evaluations.

## Conventions

- All claims must link to either official Snowflake docs or a Snowflake Builders Blog post
- Practitioner quotes use blockquote format with attribution
- Each section has "Why this matters" framing before practices
- Tables used for practice summaries; prose used for reasoning
- Keep README code samples at most 10 lines; complete configuration blocks belong
  in WORKED-EXAMPLE.md, not duplicated YAML files
- Keep the worked example focused on one sales use case; do not add features solely
  for coverage. Preserve fixture, metric, VQR, and acceptance-case consistency
- Public trust guidance distinguishes the Preview `SNOWFLAKE.TAGS.CERTIFICATION_STATUS`
  tag from the still-supported legacy tag
- README metadata is the single source for the guide's review baseline and expiry

## Key Commands

Run from the repository root. The worked-example tests require Python 3 and
PyYAML (`python3 -m pip install PyYAML` in your development environment). They
execute the portable SQL arithmetic in SQLite, not Snowflake, and do not run an Agent:

```bash
python3 .github/scripts/expire-projects.py --check
python3 .github/scripts/check-public-content.py
python3 -m unittest discover -s guide-model-agnostic-accuracy/tests -v
npm --prefix site test
```

For rendered-link checks, build the reader site first using `site/README.md`, then
run `npm --prefix site run check`. These checks validate presentation and metadata;
technical changes also require the feature-specific documentation checks below.

## Review Focus

Review semantic-view modeling guidance, Agent model availability, evaluation
versions, and announced judge retirements against current documentation. Keep
Analyst diagnostics distinct from end-to-end Agent release gates.
