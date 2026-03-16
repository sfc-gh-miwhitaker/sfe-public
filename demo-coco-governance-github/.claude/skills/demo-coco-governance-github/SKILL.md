---
name: demo-coco-governance-github
description: SQL review procedure for project standards. Use when reviewing SQL code, checking query quality, auditing naming conventions, or validating Snowflake best practices against team standards.
---

# SQL Review Procedure

Review SQL code against the project standards defined in AGENTS.md. This skill provides a step-by-step procedure -- the rules themselves live in AGENTS.md (always-on) and this skill is invoked on demand for structured review.

## When to Activate

- User asks to "review", "check", or "audit" SQL code
- User asks about query quality, naming conventions, or best practices
- User submits SQL and wants feedback before running it

## Review Procedure

### Step 1: Collect the SQL

Identify the SQL to review. If the user hasn't provided it, ask for it. Accept SQL from:
- Pasted code in the conversation
- A file path (read it)
- "Review the last query I wrote"

### Step 2: Check Query Quality

Run through each rule in order. For each violation found, quote the offending line and show the fix.

1. **SELECT * check** -- Are all columns listed explicitly? If `SELECT *` appears, flag it and list the columns from the target table.
2. **Sargable predicates** -- Are there functions wrapping columns in WHERE clauses? Flag `YEAR(col)`, `MONTH(col)`, `UPPER(col)`, `TRIM(col)` patterns and show the range-predicate alternative.
3. **QUALIFY usage** -- Is there a subquery or CTE just to filter on a window function result? Flag it and show the QUALIFY rewrite.
4. **Join type safety** -- Do join keys have matching types? Flag implicit casts (e.g., joining VARCHAR to NUMBER).
5. **Timeout safety** -- For DDL that creates warehouses, is STATEMENT_TIMEOUT_IN_SECONDS set?

### Step 3: Check Naming Conventions

1. **Warehouse names** -- Must follow `SFE_<PROJECT>_WH` pattern
2. **Table names** -- Must follow `RAW_`, `STG_`, or plain `<ENTITY>` convention
3. **Object comments** -- Every CREATE must include `COMMENT = 'DEMO: ...'` with expiration date

### Step 4: Check Security

1. **No hardcoded credentials** -- Scan for patterns: `ghp_`, `sk-`, `password`, API keys, connection strings
2. **No account identifiers** -- Scan for Snowflake locator patterns (e.g., `xy12345.us-east-1`)
3. **Attribution** -- If there's an author line, it should say `Pair-programmed by SE Community + Cortex Code`

### Step 5: Report

Format the review as:

```
## SQL Review Results

**Reviewed:** <description of what was reviewed>
**Verdict:** PASS | NEEDS FIXES (<count> issues)

### Issues Found
1. [QUALITY] <description> -- Line: <line> -- Fix: <fix>
2. [NAMING] <description> -- Fix: <fix>
...

### What Looks Good
- <positive observations>
```

If no issues are found, report PASS with positive observations only.

## Extension: Adding New Rules

When the team discovers a new pattern that should be caught:
1. Add the rule to AGENTS.md under the appropriate section
2. Add a corresponding check step in this skill under the appropriate phase
3. Open a PR so the team reviews the new rule before it applies to everyone

## Gotchas

- This skill reviews against THIS project's standards. Other projects may have different conventions.
- AGENTS.md rules are always-on (applied every session). This skill is on-demand (invoked explicitly or by trigger).
- After context compaction in long sessions, re-read AGENTS.md if standards seem forgotten.
