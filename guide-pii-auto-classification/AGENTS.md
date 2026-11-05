<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

# PII Auto-Classification Guide

Pair-programmed by SE Community + Cortex Code

## Architecture

README is a new administrator's ordered path: test one table, create a
classification profile, tag map to a company tag, custom classifier, turn
on (database or schema), tag-based masking, review, operate. Every step has
a Trust Center column and a SQL column. `sql/walkthrough.sql` builds the
whole chain on synthetic data in one Run All; `sql/teardown.sql` removes it.

## Snowflake Environment

Test account only (`sfsenorthamerica-mwhitaker_aws`), never Snowhouse.
Objects: roles PII_CLASSIFICATION_ADMIN and PII_ANALYST, warehouse
SFE_PII_CLASSIFICATION_WH, schemas SNOWFLAKE_EXAMPLE.PII_GOVERNANCE and
SNOWFLAKE_EXAMPLE.PII_DATA.

## Conventions

- Set the profile on the PII_DATA schema, never on SNOWFLAKE_EXAMPLE, so other
  demos in the shared database are not classified.
- Sample data stays obviously synthetic (example.com, 555 numbers).
- Every product claim traces to docs.snowflake.com; Preview features say so.
- README owns the review date; ELI5 mirrors README.

## Key Commands

```bash
python3 -m unittest discover -s guide-pii-auto-classification/tests -v
snow sql -c sfsenorthamerica-mwhitaker_aws -f guide-pii-auto-classification/sql/walkthrough.sql
python3 .github/scripts/expire-projects.py --check
```

Read `.claude/skills/guide-pii-auto-classification/SKILL.md` before extending.
