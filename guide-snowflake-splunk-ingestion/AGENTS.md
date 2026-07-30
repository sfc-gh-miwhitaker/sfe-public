# Snowflake → Splunk Integration Guide — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

This is a documentation-only guide. No Snowflake objects are deployed from this directory. The guide covers four integration patterns for getting Snowflake audit logs into Splunk:

1. **Federated Search** (`pattern-1-federated-search.md`) — Splunk Cloud AWS, query-in-place
2. **DB Connect** (`pattern-2-db-connect.md`) — JDBC pull with Rising Column incremental ingest
3. **External Stage** (`pattern-3-external-stage.md`) — COPY INTO S3/Azure/GCS → Splunk S3 Add-on
4. **Sentry** (`pattern-4-sentry.md`) — Run detections in Snowflake, push findings to HEC

## Key Files

| File | Purpose |
|---|---|
| `README.md` | Decision flowchart, pattern comparison table, glossary — start here |
| `pattern-1-federated-search.md` | Splunk Federated Search setup, SPL examples |
| `pattern-2-db-connect.md` | DB Connect JDBC setup, per-table Rising Column configs with SQL |
| `pattern-3-external-stage.md` | Export tasks, S3 Add-on config, deduplication |
| `pattern-4-sentry.md` | Sentry deployment, External Access Integration, HEC push procedure |

## Conventions

- SQL objects in pattern files use `SNOWFLAKE_EXAMPLE` database and `SPLUNK_EXPORT` schema to match monorepo naming conventions — update for real accounts
- PATs (Programmatic Access Tokens) are used as passwords for service accounts; key-pair auth is not supported by DB Connect
- Every SQL object has a `COMMENT` with expiration date per project standards
- Expiration: 2026-10-30

## Key Commands

No deploy script — guide only. To validate SQL syntax:
```bash
# From repo root
cat guide-snowflake-splunk-ingestion/pattern-2-db-connect.md | grep -A 30 'CREATE OR REPLACE'
```
