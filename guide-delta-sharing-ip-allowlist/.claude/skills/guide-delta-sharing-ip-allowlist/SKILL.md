---
name: guide-delta-sharing-ip-allowlist
description: "Consume a Databricks Delta Sharing feed whose provider restricts access to allowlisted IPs. Native DELTA_SHARING catalog integration vs SPCS-hosted client, SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES, shared /24 reality, bearer token lifecycle."
---

# guide-delta-sharing-ip-allowlist

## Purpose

Help a Snowflake administrator decide what to write in a vendor's "list of IP
addresses to whitelist" field when the vendor delivers data via Databricks Delta
Sharing Open Sharing, and the administrator has no Databricks workspace.

The guide's spine is an asymmetry worth re-checking on every update:
`SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES` documents three supported uses — UDF and
procedure external access, **SPCS external access and Openflow on SPCS**, and Git
integration. Catalog integrations are not among them. So the simplest path (native
`CATALOG_SOURCE = DELTA_SHARING`, GA 2026-07-21) has no allowlistable egress IP,
and the SPCS path exists solely to produce one.

## Architecture

```text
guide-delta-sharing-ip-allowlist/
  README.md         The whole deliverable, four sections, all code inline
  ELI5.md           Plain-language companion for non-technical stakeholders
  AGENTS.md         Project-specific conventions
  .claude/skills/   This skill file
```

README section order maps to the reader's decision sequence:

1. Choosing a connection path (three options, per-cloud availability matrix)
2. The SPCS client architecture (8 steps, secret through publish-by-swap)
3. What stable egress IPs really give you (the honesty section)
4. Operations and lifecycle (dated obligations, gotchas by category)

Then a "What Was Verified" table, which is load-bearing — it is the only thing
preventing a reader from treating the unvalidated container as tested.

## Key Files

| File | Role |
| ------ | ------ |
| README.md | Complete guide: decision matrix, SPCS design, egress honesty, gotchas, verification status |
| ELI5.md | Warehouse-loading-dock analogy for security reviewers and AEs |

## Snowflake Objects

This guide creates nothing. It documents these objects as inline examples:

- `CATALOG INTEGRATION ... CATALOG_SOURCE = DELTA_SHARING` with BEARER / OIDC / OAuth
- `DATABASE ... LINKED_CATALOG` (catalog-linked database, `ALLOWED_WRITE_OPERATIONS = 'NONE'`)
- `SECRET ... TYPE = GENERIC_STRING` holding the recipient profile JSON
- `NETWORK RULE ... MODE = EGRESS TYPE = HOST_PORT` — two of them, endpoint and storage
- `EXTERNAL ACCESS INTEGRATION` with `ALLOWED_AUTHENTICATION_SECRETS`
- `COMPUTE POOL`, `TASK ... AS EXECUTE JOB SERVICE` (serverless), `ALERT`

Functions referenced: `SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES`,
`SYSTEM$VERIFY_CATALOG_INTEGRATION`, `SYSTEM$LIST_NAMESPACES_FROM_CATALOG`,
`SYSTEM$LIST_ICEBERG_TABLES_FROM_CATALOG`, `SYSTEM$GET_SERVICE_LOGS`.

## Extension Playbook

### Adding a fourth connection path

1. Confirm whether the path's egress traffic is covered by the documented supported
   uses of `SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES`. If not, say so explicitly —
   that is the whole question the guide answers.
2. Add a column to the Section 1 comparison table and a branch to the mermaid
   decision flowchart.
3. Add a row to the per-cloud availability matrix if support varies by cloud.
4. Add a row to the "What Was Verified" table with an honest status.

### Updating when stable egress IPs reach GA on Azure or arrive on GCP

1. Re-run `SELECT SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES()` on an account in that
   cloud, and re-test whether the `hideAnnotations` argument is accepted.
2. Update the per-cloud availability matrix in Section 1.
3. If GCP gains support, revise the "Path C does not produce an allowlistable IP"
   statement and soften the customer-NAT recommendation for GCP accordingly.
4. Update the Section 3 Azure subsection if the `usage` field semantics change.

### Adapting the guide for a non-Delta-Sharing feed behind the same constraint

1. Keep Sections 2, 3, and 4 nearly intact — the SPCS egress pattern, the shared
   `/24` honesty, and the expiry treadmill are provider-agnostic.
2. Replace Section 1's path comparison with whatever native Snowflake option
   exists for that protocol, and re-check its egress-IP coverage.
3. Swap the Python client library and re-verify the two-hostname question: does
   the protocol redirect to a second host for data, as Delta Sharing does?

## Gotchas

- **Two hostnames, not one.** Delta Sharing returns pre-signed URLs to the
  provider's storage on a *different* host. Network rules reject wildcards, so
  both must be enumerated. Catalog listing succeeding while reads fail is the
  signature of this mistake.
- **`hideAnnotations` is Azure-only.** Confirmed live: on AWS,
  `SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES(TRUE)` errors with "does not accept (1)
  parameter". Never present the parameterised form as portable.
- **Azure `usage` field.** Ranges marked only `Network Identifier` are for Azure
  services, not for endpoints outside Azure. Sending the wrong subset produces
  silent intermittent failures.
- **Job tasks are serverless.** Do not put `WAREHOUSE =` on `CREATE TASK` when the
  body is `EXECUTE JOB SERVICE`; use `QUERY_WAREHOUSE` on the job. Also never
  `ASYNC = TRUE` — the task reports success before the container finishes.
- **Freshness gating must live in the container.** A SQL check against a staged
  copy of the provider's marker table cannot run before the first ingest, because
  the staged copy does not exist yet. Read the marker through the sharing client.
- **Secrets as env vars are not refreshed** after service creation. Mount with
  `directoryPath` so bearer token rotation reaches running containers.
- **Two allowlist entries.** The credential download link is usually IP-restricted
  too, so a human's corporate egress must be registered alongside Snowflake's.
  Missing this stalls onboarding before any Snowflake work begins.
- **The `/24` is shared** across all Snowflake accounts in the region. Raise this
  before the security reviewer finds it.
- **Full historical refresh** means overwrite-and-swap. Appending duplicates the
  dataset daily; truncating in place shows consumers an empty table.
- **SPCS ports** are limited to 22, 80, 443, and 1024+. A non-standard provider
  port outside that set fails at service creation, not at runtime.
- **Cannot create a service as ACCOUNTADMIN.** The service owner must be a normal
  role, and it is the identity for all SQL the container runs.
- **Filter metadata tables** out of the load loop; leading-underscore names are
  usually control tables.
- **DDL in this guide is not compile-checked.** Restricted session scope rejects
  `CREATE` before syntax validation, so any edit to a DDL block must be verified
  in an unrestricted scratch account and the verification table updated.
