---
name: guide-cross-cloud-account-replication
description: "Maintain the AWS-to-Azure account replication guide: failover groups, client redirect connections, cross-cloud fix-ups, cutover, and replication cost."
---

# Cross-Cloud Account Replication Guide

Pair-programmed by SE Community + Cortex Code

## Purpose

Give an administrator the fewest-step supported route to a live Azure replica
of an AWS Snowflake account, with an optional, reversible cutover.

## Architecture

Preflight (read-only) -> org admin creates BC Azure account and enables
replication on both -> source creates one failover group + connection ->
target creates replicas (initial refresh is automatic) -> verify -> optional
promote of group and connection together.

## Key Files

| File | Role |
| --- | --- |
| `README.md` | Quick Start table, prerequisites, fix-up table, cutover, cost |
| `ELI5.md` | Plain-language version |
| `sql/01_preflight.sql` | Read-only checks and generated database list |
| `sql/02_create_target.sql` | CREATE ACCOUNT + SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER |
| `sql/03_source_aws.sql` | Generated CREATE FAILOVER GROUP + CREATE CONNECTION |
| `sql/04_target_azure.sql` | AS REPLICA OF for group and connection |
| `sql/05_verify_and_cutover.sql` | Health, cost, commented cutover |
| `tests/test_guide.py` | Documentation and SQL invariants |

## Extension Playbook

1. Re-read the replication intro, config, cost, client redirect, and failover
   docs. Check the replicated-objects table for newly supported types.
2. If a new object type becomes replicable, add it to `OBJECT_TYPES` in `03`,
   compile-check, and remove it from the README "does not move" table.
3. Compile-check DDL with `only_compile`; a privilege error proves the syntax
   parsed. Never create real groups or accounts in the shared test account.
4. Update README and ELI5 together, run tests and `expire-projects.py --check`.

## Snowflake Objects

Reader-side only: account `AZURE_DR`, failover group `ACCOUNT_FG`, connection
`PRIMARY_CONN`.

## Gotchas

- Replication compute AND data transfer bill to the TARGET account; the
  transfer rate is set by the source region.
- SECURITY INTEGRATIONS in ALLOWED_INTEGRATION_TYPES requires ROLES in
  OBJECT_TYPES (compile error otherwise).
- First refresh drops target users/roles with no source match; new accounts avoid it.
- ACCOUNT_USAGE.TABLES has TABLE_TYPE and IS_HYBRID, not IS_EXTERNAL.
- Imported, personal (USER$...), and `$` system databases cannot join a group.
- Connection name must be unique across org connection AND account names.
- Snowsight wizard fails when either account uses private connectivity.
- REPLICATE/FAILOVER privileges are not replicated.
