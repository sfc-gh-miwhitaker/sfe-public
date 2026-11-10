---
name: guide-sigma-writeback-snowflake
description: "Maintain the first-time-user guide to Sigma input table writeback in Snowflake: SIGDS_ storage and edit log, warehouse views, contract views, connection setup, history snapshots, and operations."
---

# Sigma Writeback Guide

Pair-programmed by SE Community + Cortex Code

## Purpose

Explain why Sigma input table data looks unreadable in Snowflake and give a
supported pattern (warehouse view, then a typed contract view in a separate
schema) for using it safely.

## Architecture

Sigma write schema (SIGDS_<id> versioned data, SIGDS_WAL_DS_<id> edit log,
INPUT_TABLE_AUDIT_LOG_<id> view, warehouse view) -> contract view in
SIGMA_ANALYTICS -> consumers; optional daily snapshot task into a history
table. Walkthrough uses a SIGMA_LAB copy of the storage shape.

## Key Files

| File | Role |
| --- | --- |
| `README.md` | Anatomy, five steps, operate, mistakes, citations |
| `ELI5.md` | Plain-language version |
| `sql/walkthrough.sql` | One Run All, re-runnable, synthetic data |
| `sql/teardown.sql` | Removes only guide objects |
| `tests/test_guide.py` | Documentation and SQL invariants |

## Extension Playbook

1. Re-read the Sigma input tables overview, warehouse views, create input
   tables, data entry permission, and connect-to-Snowflake pages.
2. Check Sigma Tables status (public beta on 2026-11-03); update the preview
   section if it reaches GA.
3. Re-test live: Sigma SE demo instance (Okta) connected to mwhitaker_aws.
   Create an input table, edit in published mode, create a warehouse view,
   apply a filter, and inspect GET_DDL and the SIGDS_ tables as ACCOUNTADMIN.
4. Run walkthrough.sql twice on mwhitaker_aws, then the tests and
   `expire-projects.py --check`.

## Snowflake Objects

Roles SIGMA_SERVICE_ROLE, SIGMA_DATA_CONSUMER; user SIGMA_SERVICE_USER;
warehouse SFE_SIGMA_WH; schemas SNOWFLAKE_EXAMPLE.SIGMA_WRITEBACK (empty write
destination), SIGMA_LAB (lab SIGDS_ table, REGION_TARGETS stand-in view),
SIGMA_ANALYTICS (REGION_TARGETS contract view, REGION_TARGETS_HISTORY,
suspended task SNAPSHOT_REGION_TARGETS).

## Gotchas

- SIGDS_ object names are lowercase quoted identifiers; unquoted references
  fail "does not exist" (verified).
- Warehouse view is pinned to ROW_VERSION <= N and recreated by Sigma within
  seconds of published edits, with the newest edits inlined as VALUES
  literals in the DDL (verified 2026-11-10).
- Element filters carry into the warehouse view; only published changes
  apply (verified).
- Default data entry is "Editable in draft" (Sigma docs; verified).
- Clicking + in an input table saves an all-NULL row (verified).
- CREATE OR REPLACE on an upstream view reinitializes dynamic tables (docs).
- SYSADMIN cannot see another user's query history; use ACCOUNTADMIN to read
  Sigma's generated SQL.
- EXECUTE TASK is asynchronous; the walkthrough inserts the first snapshot
  directly so the validation count is immediate.
