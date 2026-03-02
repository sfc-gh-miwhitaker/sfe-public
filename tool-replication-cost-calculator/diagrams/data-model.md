# Data Model - Streamlit DR Replication Cost Calculator
Author: SE Community
Last Updated: 2025-12-08
Expires: 2026-04-10
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
Data model for pricing ingestion, normalized rates, and database metadata used by the Streamlit replication/DR cost calculator (Business Critical).

```mermaid
erDiagram
  PRICING_CURRENT {
    string service_type
    string cloud
    string region
    string unit
    number rate
    string currency
    timestamp_tz updated_at
    string updated_by
  }
  DB_METADATA {
    string database_name
    number size_tb
    timestamp as_of
  }

  PRICING_CURRENT ||--o{ DB_METADATA : "used for sizing + cost calc"
```

## Component Descriptions
- PRICING_CURRENT: Normalized pricing rows (BC rates) per service/cloud/region. Seeded by `deploy_all.sql`, editable by SYSADMIN/ACCOUNTADMIN.
- DB_METADATA: Latest database sizes from ACCOUNT_USAGE (TABLE_STORAGE_METRICS) for sizing transfer/storage.

## Change History
See `.cursor/DIAGRAM_CHANGELOG.md` for vhistory.
