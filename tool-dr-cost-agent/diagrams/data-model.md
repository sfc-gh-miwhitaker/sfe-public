# Data Model - DR Cost Agent
Author: SE Community
Last Updated: 2026-03-04
Expires: 2026-05-01
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
Data model for pricing, database metadata, hybrid table inventory, and replication history used by the DR Cost Agent.

```mermaid
erDiagram
  PRICING_CURRENT {
    string service_type PK
    string cloud PK
    string region PK
    string unit PK
    number rate
    string currency
    timestamp_tz updated_at
    string updated_by
  }
  DB_METADATA_V2 {
    string database_name PK
    number total_size_tb
    number hybrid_excluded_tb
    number replicable_size_tb
    number hybrid_table_count
    boolean has_hybrid_tables
    timestamp as_of
  }
  HYBRID_TABLE_METADATA {
    string database_name FK
    string table_schema
    string table_name
    number bytes
    number size_gb
    timestamp created_at
    timestamp last_altered_at
  }
  REPLICATION_HISTORY {
    string replication_group_name
    number replication_group_id PK
    timestamp start_time PK
    timestamp end_time
    date usage_date
    date usage_month
    number credits_used
    number bytes_transferred
    number tb_transferred
  }

  DB_METADATA_V2 ||--o{ HYBRID_TABLE_METADATA : "contains"
  PRICING_CURRENT ||--o{ DB_METADATA_V2 : "rates applied to"
```

## Component Descriptions
- **PRICING_CURRENT**: Normalized pricing rows (BC rates) per service/cloud/region. Includes HYBRID_STORAGE for the simplified March 2026 pricing model.
- **DB_METADATA_V2**: Database sizes with hybrid table exclusion. REPLICABLE_SIZE_TB = TOTAL_SIZE_TB minus HYBRID_EXCLUDED_TB.
- **HYBRID_TABLE_METADATA**: Individual hybrid table detail from ACCOUNT_USAGE. Hybrid tables are skipped during replication refresh (BCR-1560-1582).
- **REPLICATION_HISTORY**: Actual replication usage from ACCOUNT_USAGE (empty if no replication configured).
