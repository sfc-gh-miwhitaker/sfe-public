# Data Model - Cortex Trail
Author: SE Community
Last Updated: 2026-01-05
Expires: See deploy_all.sql (single source of truth)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
This diagram shows the data model for Cortex Trail, including the read-only `SNOWFLAKE.ACCOUNT_USAGE` sources, the monitoring and analytics views in `SNOWFLAKE_EXAMPLE.CORTEX_USAGE`, the snapshot table, and the ML-based forecasting model and outputs.

```mermaid
erDiagram
  %% Source layer (read-only): SNOWFLAKE.ACCOUNT_USAGE
  CORTEX_ANALYST_USAGE_HISTORY ||--o{ V_CORTEX_ANALYST_DETAIL : provides
  CORTEX_SEARCH_DAILY_USAGE_HISTORY ||--o{ V_CORTEX_SEARCH_DETAIL : provides
  CORTEX_SEARCH_SERVING_USAGE_HISTORY ||--o{ V_CORTEX_SEARCH_SERVING_DETAIL : provides
  CORTEX_AISQL_USAGE_HISTORY ||--o{ V_CORTEX_FUNCTIONS_DETAIL : provides
  CORTEX_AISQL_USAGE_HISTORY ||--o{ V_CORTEX_FUNCTIONS_QUERY_DETAIL : provides
  CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY ||--o{ V_CORTEX_DOCUMENT_PROCESSING_DETAIL : provides
  CORTEX_FINE_TUNING_USAGE_HISTORY ||--o{ V_CORTEX_FINE_TUNING_DETAIL : provides
  METERING_DAILY_HISTORY ||--o{ V_METERING_AI_SERVICES : provides

  %% Rollups + export
  V_CORTEX_ANALYST_DETAIL ||--o{ V_CORTEX_DAILY_SUMMARY : aggregates
  V_CORTEX_SEARCH_DETAIL ||--o{ V_CORTEX_DAILY_SUMMARY : aggregates
  V_CORTEX_SEARCH_SERVING_DETAIL ||--o{ V_CORTEX_DAILY_SUMMARY : aggregates
  V_CORTEX_FUNCTIONS_DETAIL ||--o{ V_CORTEX_DAILY_SUMMARY : aggregates
  V_CORTEX_DOCUMENT_PROCESSING_DETAIL ||--o{ V_CORTEX_DAILY_SUMMARY : aggregates
  V_CORTEX_FINE_TUNING_DETAIL ||--o{ V_CORTEX_DAILY_SUMMARY : aggregates
  V_CORTEX_DAILY_SUMMARY ||--o{ V_CORTEX_COST_EXPORT : exports

  %% Snapshot storage + history view
  V_CORTEX_DAILY_SUMMARY ||--o{ CORTEX_USAGE_SNAPSHOTS : materialized_by_task
  CORTEX_USAGE_SNAPSHOTS ||--o{ V_CORTEX_USAGE_HISTORY : queried_by

  %% User attribution (join via QUERY_HISTORY)
  QUERY_HISTORY ||--o{ V_USER_SPEND_ATTRIBUTION : joins_on_query_id
  CORTEX_AISQL_USAGE_HISTORY ||--o{ V_USER_SPEND_ATTRIBUTION : joins_on_query_id
  CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY ||--o{ V_USER_SPEND_ATTRIBUTION : joins_on_query_id
  V_USER_SPEND_ATTRIBUTION ||--o{ V_USER_SPEND_SUMMARY : aggregates
  V_USER_SPEND_ATTRIBUTION ||--o{ V_USER_FEATURE_USAGE : aggregates

  %% Forecasting (daily credits by service)
  CORTEX_USAGE_SNAPSHOTS ||--o{ V_FORECAST_INPUT : aggregates
  V_FORECAST_INPUT ||--|| CORTEX_USAGE_FORECAST_MODEL : trains
  CORTEX_USAGE_FORECAST_MODEL ||--o{ V_USAGE_FORECAST_12M : produces

  %% Key entities (selected columns)
  QUERY_HISTORY {
    varchar query_id
    timestamp_ltz start_time
    varchar user_name
  }

  CORTEX_AISQL_USAGE_HISTORY {
    varchar query_id
    varchar function_name
    varchar model_name
    number tokens
    number token_credits
  }

  CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY {
    varchar query_id
    varchar function_name
    varchar model_name
    number credits_used
    number page_count
  }

  CORTEX_USAGE_SNAPSHOTS {
    date snapshot_date
    date usage_date
    varchar service_type
    number total_credits
    number total_operations
    varchar function_name
    varchar model_name
    timestamp_ltz inserted_at
  }

  V_USER_SPEND_ATTRIBUTION {
    date usage_date
    varchar user_name
    varchar service_type
    varchar feature_name
    varchar model_name
    number credits_used
    number operations
  }

  V_USAGE_FORECAST_12M {
    varchar service_type
    date forecast_date
    number forecast_credits
    number lower_bound_credits
    number upper_bound_credits
  }
```

## Component Descriptions
- **AccountUsageSources**: Snowflake-managed usage/billing telemetry (read-only). Location: `SNOWFLAKE.ACCOUNT_USAGE.*`. Deps: `IMPORTED PRIVILEGES` on database `SNOWFLAKE`.
- **MonitoringAndSnapshots**: Project objects in `SNOWFLAKE_EXAMPLE.CORTEX_USAGE` created by `sql/01_deployment/deploy_cortex_monitoring.sql`. Stores historical metrics in `CORTEX_USAGE_SNAPSHOTS`.
- **UserAttributionViews**: `V_USER_SPEND_ATTRIBUTION`, `V_USER_SPEND_SUMMARY`, `V_USER_FEATURE_USAGE` attribute credits to users by joining usage to `QUERY_HISTORY` on `QUERY_ID`.
- **ForecastingModel**: `CORTEX_USAGE_FORECAST_MODEL` (Snowflake ML forecasting) trained from `V_FORECAST_INPUT` and exposed via `V_USAGE_FORECAST_12M`.
- **StreamlitApp**: UI reads rollups, attribution, and forecast views. Location: `streamlit/cortex_cost_calculator/streamlit_app.py`.

## Change History
See git history for changes to this diagram.
