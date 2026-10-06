---
name: guide-cortex-model-policy
description: "Maintain the approved-models guide: Cortex model filtering, model application roles, bootstrap opt-out, approved-only policy, and model picker verification."
---

# Cortex Model Policy Guide

Pair-programmed by SE Community + Cortex Code

## Purpose

Give administrators a short, approval-first route from model inventory to an
explicit approved-model policy without changing unrelated feature access.

## Architecture

Read-only metadata -> administrator selects exact model IDs and execution roles ->
reviewed grants/revokes -> non-admin and real-application acceptance tests.
The SQL emits strings only; account changes live in clearly marked README steps.

## Key Files

| File | Role |
| --- | --- |
| `README.md` | Policy, quick start, change sequence, CoCo prompt, acceptance |
| `ELI5.md` | Plain-language explanation of the same boundaries |
| `sql/01_inventory.sql` | Read-only inspection and generated SQL menu |
| `docs/01-OPERATIONS.md` | Targeted revokes, execution contexts, recovery |
| `tests/test_guide.py` | Metadata-only SQL and documentation invariants |
| `AGENTS.md` | Project-specific maintenance instructions |

## How to Update Model-Control Guidance

1. Re-read public model access docs, BCR-2378, bundle history, SHOW command docs,
   and AI_COMPLETE error behavior. Distinguish announced dates from enforcement.
2. Load the SQL and governance skills. Validate metadata queries read-only;
   compile inference examples without executing excluded-model calls.
3. Keep model names generated from the reader's account. Do not add an inferred
   approved-vendor list or copy internal model inventories into public text.
4. Preserve grant-before-revoke ordering, the two PUBLIC paths, and explicit
   inspection of unapproved model grants and inherited/secondary role paths.
5. Update README and ELI5 together. Run focused tests and site checks, then audit
   under the guide requirements of sfe-demo-standards and applyrules.

## Snowflake Objects

No project objects. Uses `SNOWFLAKE.MODELS`, model application roles,
`SNOWFLAKE.PUBLIC`, account `PUBLIC`, and existing execution roles.

## Gotchas

- Removing a direct PUBLIC grant leaves the bootstrap; its dedicated procedure
  persists opt-out across upgrades.
- ALL includes future models. A single-model revoke cannot subtract from ALL.
- ACCOUNTADMIN is exempt; MANAGE GRANTS can expose more catalog metadata.
- SHOW CORTEX BASE MODELS needs explicit schema scope.
- Special-purpose and embedding model names are not necessarily AI_COMPLETE models.
- AI_COMPLETE can return null or error details rather than throw; unrelated
  failures do not prove denial.
- PUBLIC is a baseline, not a ceiling or a guarantee for every execution context.
- Changing cross-region settings or the entire BCR bundle is out of this recipe.
