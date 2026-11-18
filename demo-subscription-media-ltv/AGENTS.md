# Subscription Media LTV — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Synthetic subscription publisher data feeds a governed `MEMBER_VALUE` view, a
Snowflake ML churn model, and two semantic views. Two Cortex Agents sit on top:
`MEMBER_VALUE_AGENT` (governed semantic view) and `RAW_DATA_AGENT` (bare tables,
for contrast). Both are attached to the account's CoWork object.

## Snowflake Environment

- Database: SNOWFLAKE_EXAMPLE
- Schema: SUBSCRIPTION_MEDIA_LTV
- Semantic views: SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_SUBSCRIPTION_MEDIA_LTV_MEMBER_VALUE and SV_SUBSCRIPTION_MEDIA_LTV_RAW
- Warehouse: SFE_SUBSCRIPTION_MEDIA_LTV_WH

## Conventions

- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup, including CoWork detach
- `sql/` -- Individual SQL scripts, run in numeric order
- `.claude/skills/` -- Project-specific AI skill
- Data is pinned to an as-of date of 2026-10-31 and seeded with `HASH(member_id, salt)`. Never use `RANDOM()` or `CURRENT_DATE()` in data generation; the demo script quotes exact values.
- Business definitions live in `MEMBER_VALUE` and nowhere else. Semantic view facts wrap them with mature-cohort filters.
- Verified query SQL uses logical table and fact names, not physical names.
- `docs/01-DEMO-SCRIPT.md` lists expected answers. Update it whenever data generation or definitions change.

## Key Commands

```bash
# Run one script against a test account
snow sql -c <connection> --role SYSADMIN --warehouse SFE_SUBSCRIPTION_MEDIA_LTV_WH -f sql/04_cortex/02_semantic_views.sql

# Static checks
python3 -m unittest discover -s demo-subscription-media-ltv/tests
```

## Helping New Users

If the user seems unsure where to start:

1. Explain in one sentence: this demo shows an AI assistant answering subscription value questions correctly because the business definitions live in Snowflake.
2. Ask whether they have run `deploy_all.sql` in Snowsight yet.
3. If not, walk them through opening a SQL worksheet, pasting the file, and selecting **Run All**.
4. Then suggest opening CoWork as SYSADMIN and asking **Member Value Analyst** the questions in `docs/01-DEMO-SCRIPT.md`.
