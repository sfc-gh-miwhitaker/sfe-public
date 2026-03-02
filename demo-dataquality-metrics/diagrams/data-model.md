# Data Model - Data Quality Metrics & Reporting Demo

Author: SE Community
Last Updated: 2026-01-15
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

**Reference Implementation:** This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview

This diagram shows the core data tables used for data quality monitoring, including raw data sources and the metrics table that records validation outcomes.

## Diagram

```mermaid
erDiagram
  RAW_ATHLETE_PERFORMANCE ||--o{ STG_DATA_QUALITY_METRICS : monitors
  RAW_FAN_ENGAGEMENT ||--o{ STG_DATA_QUALITY_METRICS : monitors

  RAW_ATHLETE_PERFORMANCE {
    string athlete_id PK
    string ngb_code
    string sport
    date event_date
    string metric_type
    float metric_value
    string data_source
    timestamp load_timestamp
  }

  RAW_FAN_ENGAGEMENT {
    string engagement_id PK
    string fan_id
    string channel
    string event_type
    timestamp engagement_timestamp
    int session_duration
    boolean conversion_flag
  }

  STG_DATA_QUALITY_METRICS {
    date metric_date
    string table_name
    string metric_name
    float metric_value
    int records_evaluated
    int failures_detected
  }
```

## Component Descriptions

- RAW_ATHLETE_PERFORMANCE: Raw performance metrics collected from partner systems and uploads.
- RAW_FAN_ENGAGEMENT: Raw engagement events captured from digital channels.
- STG_DATA_QUALITY_METRICS: Daily metric results produced by data quality checks.

## Change History

See `.cursor/DIAGRAM_CHANGELOG.md` for version history.
