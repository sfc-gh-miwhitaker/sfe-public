# Network Flow - Cortex Trail
Author: SE Community
Last Updated: 2026-01-05
Expires: See deploy_all.sql (single source of truth)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
This diagram shows the network connectivity for Cortex Trail. All analytics run natively inside Snowflake. External connectivity is limited to HTTPS access to Snowsight and optional GitHub access for Git-integrated deployment.

```mermaid
graph TB
  subgraph external [External]
    User[UserBrowser]
    GitHub[GitHubRepo]
  end

  subgraph snowflake [SnowflakeAccount]
    Snowsight[SnowsightUI]
    Warehouse[VirtualWarehouse]

    subgraph projectDb [SNOWFLAKE_EXAMPLE]
      ProjectSchema[CORTEX_USAGE_Schema]
      Streamlit[StreamlitApp_CORTEX_COST_CALCULATOR]
      Views[ViewsAndModels]
      Snapshots[(CORTEX_USAGE_SNAPSHOTS)]
      Task[ServerlessTask_TASK_DAILY_CORTEX_SNAPSHOT]
      MLModel[CORTEX_USAGE_FORECAST_MODEL]
    end

    SystemDb[SNOWFLAKE_SystemDatabase]
    AccountUsage[ACCOUNT_USAGE]
  end

  %% External access
  User -->|"HTTPS_443"| Snowsight
  Snowsight -->|"HTTPS_443"| User

  %% Optional Git-integrated deployment (deploy_all.sql)
  Snowsight -->|"HTTPS_443_git_fetch"| GitHub

  %% In-account execution
  Snowsight --> Views
  Views --> AccountUsage
  AccountUsage --> SystemDb

  %% Snapshots (serverless)
  Task --> Views
  Task --> Snapshots
  Snapshots --> Views

  %% Forecasting (in-account)
  Views --> MLModel
  MLModel --> Views

  %% Streamlit queries run via a warehouse
  Streamlit -->|"queries"| Views
  Streamlit -->|"queries"| Snapshots
  Streamlit -->|"uses"| Warehouse
```

## Component Descriptions
- **UserBrowser**: End users access Snowsight and Streamlit over HTTPS (port 443).
- **SnowsightUI**: Primary UI for deployment and operation. Runs SQL worksheets and hosts Streamlit apps.
- **GitHubRepo**: Optional source for Git-integrated deployment (public repo fetch). No runtime dependency after objects are created.
- **ViewsAndModels**: Project views (monitoring, attribution, forecast outputs) and the ML forecasting model inside `SNOWFLAKE_EXAMPLE.CORTEX_USAGE`.
- **ServerlessTask_TASK_DAILY_CORTEX_SNAPSHOT**: Serverless task that merges daily metrics into `CORTEX_USAGE_SNAPSHOTS`.

## Change History
See git history for changes to this diagram.
