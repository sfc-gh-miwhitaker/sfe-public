# Data Flow - Cortex Trail
Author: SE Community
Last Updated: 2026-01-05
Expires: See deploy_all.sql (single source of truth)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
This diagram shows how Cortex usage telemetry flows from Snowflake `ACCOUNT_USAGE` into project views and snapshots in `SNOWFLAKE_EXAMPLE.CORTEX_USAGE`, then into two primary outcomes: user spend attribution (user to feature to credits) and a 12-month forecast of credits by service.

```mermaid
graph TB
  subgraph accountUsage [SNOWFLAKE.ACCOUNT_USAGE]
    AU_Analyst[CORTEX_ANALYST_USAGE_HISTORY]
    AU_AISQL[CORTEX_AISQL_USAGE_HISTORY]
    AU_DocProc[CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY]
    AU_SearchDaily[CORTEX_SEARCH_DAILY_USAGE_HISTORY]
    AU_SearchServing[CORTEX_SEARCH_SERVING_USAGE_HISTORY]
    AU_FineTuning[CORTEX_FINE_TUNING_USAGE_HISTORY]
    AU_QueryHistory[QUERY_HISTORY]
    AU_Metering[METERING_DAILY_HISTORY]
  end

  subgraph projectSchema [SNOWFLAKE_EXAMPLE.CORTEX_USAGE]
    Views[MonitoringViews]
    DailySummary[V_CORTEX_DAILY_SUMMARY]
    CostExport[V_CORTEX_COST_EXPORT]
    Snapshots[(CORTEX_USAGE_SNAPSHOTS)]
    History[V_CORTEX_USAGE_HISTORY]

    UserAttrib[V_USER_SPEND_ATTRIBUTION]
    UserSummary[V_USER_SPEND_SUMMARY]
    UserFeatures[V_USER_FEATURE_USAGE]

    ForecastInput[V_FORECAST_INPUT]
    ForecastModel[CORTEX_USAGE_FORECAST_MODEL]
    ForecastView[V_USAGE_FORECAST_12M]
  end

  subgraph appLayer [StreamlitInSnowflake]
    App[StreamlitApp_CORTEX_COST_CALCULATOR]
    CsvExport[export_metrics.sql]
  end

  %% Monitoring views and rollups
  AU_Analyst --> Views
  AU_AISQL --> Views
  AU_DocProc --> Views
  AU_SearchDaily --> Views
  AU_SearchServing --> Views
  AU_FineTuning --> Views
  AU_Metering --> Views
  Views --> DailySummary
  DailySummary --> CostExport

  %% Snapshots
  DailySummary -->|"daily_task_merges"| Snapshots
  Snapshots --> History

  %% User attribution (query_id joins)
  AU_AISQL --> UserAttrib
  AU_DocProc --> UserAttrib
  AU_QueryHistory --> UserAttrib
  UserAttrib --> UserSummary
  UserAttrib --> UserFeatures

  %% Forecasting
  Snapshots --> ForecastInput
  ForecastInput --> ForecastModel
  ForecastModel --> ForecastView

  %% App consumption
  CostExport --> App
  History --> App
  UserSummary --> App
  UserFeatures --> App
  ForecastView --> App

  %% SE workflow export path
  CostExport --> CsvExport
  CsvExport --> App
```

## Component Descriptions
- **AccountUsage**: Read-only system views providing authoritative usage/credit telemetry. Location: `SNOWFLAKE.ACCOUNT_USAGE.*`.
- **MonitoringViews**: SQL views that normalize and aggregate per-service usage, then roll into `V_CORTEX_DAILY_SUMMARY`. Location: `sql/01_deployment/deploy_cortex_monitoring.sql`.
- **UserAttribution**: Views that attribute usage to `USER_NAME` by joining usage (via `QUERY_ID`) to `QUERY_HISTORY`. Location: `sql/01_deployment/deploy_cortex_monitoring.sql`.
- **SnapshotsAndHistory**: Daily snapshots stored in `CORTEX_USAGE_SNAPSHOTS`, queried via `V_CORTEX_USAGE_HISTORY` for faster historical analysis and longer retention.
- **Forecasting**: `V_FORECAST_INPUT` aggregates daily credits by service from snapshots, trains `CORTEX_USAGE_FORECAST_MODEL`, and exposes results in `V_USAGE_FORECAST_12M`.
- **StreamlitApp**: Interactive UI that answers the two primary questions (user attribution and 12-month forecast). Location: `streamlit/cortex_cost_calculator/streamlit_app.py`.

## Change History
See git history for changes to this diagram.
