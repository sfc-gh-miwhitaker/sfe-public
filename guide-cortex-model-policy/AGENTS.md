<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

# Cortex Model Policy Guide

Pair-programmed by SE Community + Cortex Code

## Architecture

README is the administrator's ordered workflow. The SQL inventory reads metadata
and emits proposed commands as strings; it does not apply policy or call a model.
The operations page handles inherited grants, surface testing, and recovery.

## Snowflake Environment

No deployed objects. Reads SNOWFLAKE model metadata and existing account roles.
Policy changes belong in the reader's target account under administrator approval.

## Conventions

- Explicit approved model IDs, not a vendor denylist or generated blanket approval.
- Keep SNOWFLAKE.PUBLIC bootstrap and customer-managed PUBLIC grants distinct.
- Keep the 2026_07 enforcement condition tied to bundle state, not a past date.
- Generated grants target PUBLIC as a baseline, not as a role-inheritance ceiling.
- Keep tests for denied authorization separate from availability and null results.
- Treat developer provenance and inference geography as separate facts.
- README owns the review date; internal inventory results do not belong in examples.

## Key Commands

```bash
python3 -m unittest discover -s guide-cortex-model-policy/tests -v
npm --prefix site test
```

Read `.claude/skills/guide-cortex-model-policy/SKILL.md` before extending the workflow.
