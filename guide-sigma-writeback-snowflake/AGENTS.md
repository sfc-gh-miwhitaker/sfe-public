<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

# Sigma Writeback Guide

Pair-programmed by SE Community + Cortex Code

## Architecture

README walks a first-time Sigma + Snowflake user from "what are these SIGDS_
tables" to a governed contract layer: anatomy of the write schema, connection
setup, input table habits, warehouse view behavior, contract view, history,
operations. `sql/walkthrough.sql` reproduces the storage shape on synthetic
data in SIGMA_LAB and builds the contract layer in one Run All;
`sql/teardown.sql` removes it.

## Snowflake Environment

Test account only (`sfsenorthamerica-mwhitaker_aws`), never Snowhouse.
Objects: roles SIGMA_SERVICE_ROLE and SIGMA_DATA_CONSUMER, user
SIGMA_SERVICE_USER, warehouse SFE_SIGMA_WH, schemas
SNOWFLAKE_EXAMPLE.SIGMA_WRITEBACK, SIGMA_LAB, SIGMA_ANALYTICS.

## Conventions

- Sigma behavior claims come from Sigma docs or a recorded live test; never
  infer Sigma internals beyond what was observed.
- The SIGMA_LAB table is a teaching copy; never tell readers to query real
  SIGDS_ tables in production.
- No customer names anywhere. Sample data stays synthetic (example.com).
- README owns the review date; ELI5 mirrors README.

## Key Commands

```bash
python3 -m unittest discover -s guide-sigma-writeback-snowflake/tests -v
snow sql -c sfsenorthamerica-mwhitaker_aws -f guide-sigma-writeback-snowflake/sql/walkthrough.sql
python3 .github/scripts/expire-projects.py --check
```

Read `.claude/skills/guide-sigma-writeback-snowflake/SKILL.md` before extending.
