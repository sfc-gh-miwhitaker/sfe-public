# Cortex Code Budget Guide — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

7-part guide covering every form of Cortex Code cost control.

```
parts/  — numbered walkthrough files (01 → 07)
sql/    — standalone copy-paste SQL reference (no deploy required)
README.md — overview, part table, quick reference
```

Data flow: `SNOWFLAKE.ACCOUNT_USAGE` views → users read and run SQL manually.
No Snowflake objects are created by this guide.

## Conventions

- SQL files are standalone — no deploy required; users run against their own account
- Each SQL file header identifies which part(s) it supports
- Parts link forward/back: every part ends with "Next: Part N"
- SQL snippets in parts/ reference the matching sql/ file for the full version
- Placeholders use `<angle_bracket>` format — never hardcoded values

## Key Commands

```bash
# Sparse clone to read this guide locally
git clone --filter=blob:none --sparse https://github.com/sfc-gh-miwhitaker/sfe-public.git
cd sfe-public
git sparse-checkout add guide-cortex-code-budget

# Or with CoCo
cortex "Walk me through Part 3 of the Cortex Code budget guide"
```
