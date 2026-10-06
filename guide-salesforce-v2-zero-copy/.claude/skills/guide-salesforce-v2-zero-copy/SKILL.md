---
name: guide-salesforce-v2-zero-copy
description: Maintain or extend the Salesforce and Snowflake zero-copy guide. Use for Salesforce V2, Snowflake V2 data share targets, Data 360 federation, Salesforce Data Cloud zero copy, or Zerocopy Connector guidance.
---

# Salesforce V2 Zero-Copy Guide

Pair-programmed by SE Community + Cortex Code

## Purpose

Maintain the public guide that separates the two zero-copy directions, Salesforce
V2 data sharing, legacy BYOL, Openflow replication, and Salesforce MCP.

## Architecture

The guide documents two directional paths:

`Salesforce Data Share -> Snowflake V2 Data Share Target -> Enrollment ID ->`
`Snowflake ZEROCOPY CONNECTOR -> catalog-linked database -> queryable views`

`Snowflake data -> Salesforce query or file federation -> external DLO -> DMO`

## Key Files

- `README.md`: Decision guide, setup runbook, SQL, limitations, and references.
- `ELI5.md`: Plain-language explanation for mixed technical audiences.
- `AGENTS.md`: Project-specific maintenance constraints.

## Extension Playbook: Add a New Capability

1. Find the current public Snowflake and Salesforce documentation.
2. Identify the direction and mechanism: V2 Data Share, query/file federation,
   legacy V1, Openflow, or MCP.
3. Verify availability, cloud/region support, prerequisites, and limitations.
4. Update the comparison table and the relevant runbook section.
5. Add only stable public links under External References.
6. Move the guide expiration date forward only after re-verification.
7. Run the repository compliance checks.

## Snowflake Objects

- `ZEROCOPY CONNECTOR`
- Catalog-linked database created with `LINKED_ZEROCOPY_CONNECTOR`
- Salesforce data products exposed as Snowflake views
- Snowflake objects exposed to Salesforce through a separate federation connection

## Gotchas

- Bidirectional zero copy consists of separate directional configurations.
- `BYOL` and a legacy Snowflake Data Share Target refer to the old V1 route.
- Salesforce V2 zero-copy requires Salesforce Data Cloud/Data 360.
- Openflow copies Salesforce objects into Snowflake; it is not zero-copy.
- Salesforce MCP is an agent tool path; it is not data movement.
- Link and verify V2 before unlinking a legacy target.
- Connector and catalog-linked database objects do not support `UNDROP`.
- Do not publish internal-only compatibility flags or roadmap claims.
- Do not claim Streams or Dynamic Tables compatibility without current public evidence.
