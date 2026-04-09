# Data Flow - DR Cost Agent
Author: SE Community
Last Updated: 2026-04-09
Expires: 2026-05-01
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
Data ingestion and processing flow for DR/replication cost estimation using Snowflake Intelligence.

```mermaid
graph TB
  subgraph accountUsage [SNOWFLAKE.ACCOUNT_USAGE]
    TSM[(TABLE_STORAGE_METRICS)]
    HT[(HYBRID_TABLES)]
    RGUH[(REPLICATION_GROUP_USAGE_HISTORY)]
  end

  subgraph infoSchema [INFORMATION_SCHEMA]
    ISD[(DATABASES)]
  end

  subgraph drCostAgent [SNOWFLAKE_EXAMPLE.DR_COST_AGENT]
    Pricing[(PRICING_CURRENT<br/>60 baseline rates)]
    DBMeta[(DB_METADATA_V2<br/>Hybrid-aware sizes)]
    HybridMeta[(HYBRID_TABLE_METADATA<br/>Per-table inventory)]
    ReplHist[(REPLICATION_HISTORY<br/>Actual costs)]
    CostProj[COST_PROJECTION<br/>SPROC]
  end

  subgraph semanticModels [SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS]
    SV[SV_DR_COST<br/>Semantic View]
  end

  subgraph agentLayer [Snowflake Intelligence]
    Agent[DR_COST_AGENT]
  end

  TSM --> DBMeta
  HT --> DBMeta
  HT --> HybridMeta
  ISD --> DBMeta
  RGUH --> ReplHist

  Pricing --> SV
  DBMeta --> SV
  HybridMeta --> SV
  ReplHist --> SV

  SV -->|Cortex Analyst| Agent
  CostProj -->|Custom Tool| Agent
  Agent -->|"Charts + Tables"| User[End User]
```

## Component Descriptions

### Data Foundation
- **PRICING_CURRENT**: Baseline BC rates per cloud/region/service type (seeded by deploy.sql)
- **DB_METADATA_V2**: Per-database sizes with hybrid table exclusion for accurate replication sizing
- **HYBRID_TABLE_METADATA**: Individual hybrid table inventory (skipped during replication)
- **REPLICATION_HISTORY**: Actual replication credits and bytes from ACCOUNT_USAGE

### Semantic Layer
- **SV_DR_COST**: Semantic view powering Cortex Analyst for natural language queries

### Agent Layer
- **DR_COST_AGENT**: Snowflake Intelligence agent with three tools:
  - Cortex Analyst (structured data queries via semantic view)
  - COST_PROJECTION (deterministic projection SPROC)
  - data_to_chart (built-in visualization)
