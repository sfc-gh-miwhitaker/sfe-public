# Data Flow - Data Quality Metrics & Reporting Demo

Author: SE Community
Last Updated: 2026-03-02
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

**Reference Implementation:** This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview

This diagram shows how source data is ingested into Snowflake, monitored via Streams and Tasks, and visualized in a Streamlit dashboard.

## Diagram

```mermaid
graph LR
  subgraph "Sources"
    Uploads[Manual Uploads]
    Partners[Partner Systems]
  end

  subgraph "Ingestion - SNOWFLAKE_EXAMPLE.DATA_QUALITY"
    RawAthlete[(RAW_ATHLETE_PERFORMANCE)]
    RawFan[(RAW_FAN_ENGAGEMENT)]
  end

  subgraph "Monitoring"
    StreamAthlete[RAW_ATHLETE_PERFORMANCE_STREAM]
    StreamFan[RAW_FAN_ENGAGEMENT_STREAM]
    Task[refresh_data_quality_metrics_task]
    Metrics[(STG_DATA_QUALITY_METRICS)]
  end

  subgraph "Consumption"
    Views[V_QUALITY_SCORE_TREND]
    App[Streamlit Dashboard]
  end

  Uploads --> RawAthlete
  Partners --> RawFan
  RawAthlete --> StreamAthlete
  RawFan --> StreamFan
  StreamAthlete --> Task
  StreamFan --> Task
  Task --> Metrics
  Metrics --> Views
  Views --> App
```

## Component Descriptions

- Sources: Incoming data from uploads and partner systems.
- Monitoring: Streams capture incremental changes and Tasks compute quality metrics.
- Consumption: Views support dashboards and analyst queries.

## Change History

See `.cursor/DIAGRAM_CHANGELOG.md` for version history.
