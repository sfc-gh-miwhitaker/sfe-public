---
name: guide-universal-data-sharing
description: "Guide covering Snowflake 2026 universal data sharing enhancements: Open Data Sharing for non-Snowflake consumers via IRC/PAT, Open Table Format Sharing (Iceberg/Delta cross-cloud), multi-party Data Clean Rooms Collaboration API, universal governance via Horizon Catalog Scan Plan API, and AI-powered sharing with auto-gen agents. Use when: non-Snowflake partner sharing, external consumer access, open data sharing, multi-party clean room, symmetric collaboration, Iceberg REST Catalog sharing, universal governance, agent sharing."
---

# Universal Data Sharing — Project Skill

## Purpose

SE guide framed as "what you missed behind all the other Summit 2026 announcements." Covers how Snowflake eliminated the requirement for consumers to have a Snowflake account, enabled symmetric N-party Clean Rooms, and made governance policies follow data across engines.

## Architecture

Documentation guide with companion SQL examples — no deployed Snowflake objects.

```
README.md                              → main guide (start here)
sql/01_open_data_sharing.sql           → EXTERNAL CONSUMER + PAT + EXTERNAL LISTING workflow
sql/02_open_table_format_sharing.sql   → Iceberg/Delta + Cross-Cloud Auto-Fulfillment
sql/03_collaboration_api_dcr.sql       → Collaboration API INITIALIZE call
sql/04_universal_governance.sql        → Scan Plan API + Spark Connector policy enforcement
ELI5.md                                → plain-language companion
AGENTS.md                              → project-specific AI instructions
```

## Key Files

| File | Role |
|---|---|
| `README.md` | Full narrative guide — decision tree, feature matrix, SQL walkthroughs |
| `sql/01_open_data_sharing.sql` | The headline new workflow: share with non-Snowflake consumers |
| `sql/02_open_table_format_sharing.sql` | Cross-cloud Iceberg/Delta sharing |
| `sql/03_collaboration_api_dcr.sql` | Key Collaboration API calls + architecture context |
| `sql/04_universal_governance.sql` | Policies on external engines |
| `ELI5.md` | Plain-language companion for non-technical stakeholders |

## Snowflake Objects

None. Reference guide only.

## Extension Playbook: Adding a New Sharing Pattern Section

When Snowflake GAs a new sharing capability or you learn a new pattern:

1. Create a new SQL file in `sql/` following the naming convention `NN_<pattern>.sql`.
2. Add a new section in `README.md` following the structure: What → How → Status → Key SQL → Link to docs.
3. Add a row to the Feature Status Matrix in `README.md`.
4. Add the pattern to the "When to Use What" decision tree.
5. Update this SKILL.md: add the new file to the Architecture section and Key Files table.

## Gotchas

- **Open Data Sharing is Public Preview (Jul 2026).** Single-region only during Private Preview phase; public preview expanding regions. Do not position as GA.
- **PATs are the only auth method for external consumers during preview.** Other methods planned but not available yet.
- **Legacy Clean Rooms deprecated Oct 2026.** No new legacy clean rooms via UI after 2026-10-01. Collaboration API is the replacement.
- **Scan Plan API is Private Preview.** The mechanism for enforcing row-access/masking on external engines. Do not promise GA timeline.
- **Snowflake Connector for Apache Spark (GA) is the "today" answer** for customers who need policy enforcement on Spark without waiting for Scan Plan API.
- **Auto-gen Agents for Data Shares is Public Preview.** Generates Semantic View + Agent automatically from any listing/share. Production-ready but preview status.
- **Catalog federation does not support catalog-linked databases yet.** Limitation for open table format sharing with externally-managed catalogs.
