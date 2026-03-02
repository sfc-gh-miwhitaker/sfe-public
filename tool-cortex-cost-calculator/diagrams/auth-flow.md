# Auth Flow - Cortex Trail
Author: SE Community
Last Updated: 2026-01-05
Expires: See deploy_all.sql (single source of truth)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
This diagram shows authentication and authorization for Cortex Trail. Users authenticate to Snowflake, then RBAC controls the ability to deploy (create schema objects, tasks, and optionally an ML forecast model) and to query the views and Streamlit app.

```mermaid
sequenceDiagram
  actor User as User
  participant Snowsight as Snowsight
  participant Auth as SnowflakeAuth
  participant RBAC as SnowflakeRBAC
  participant SysDb as SNOWFLAKE_SystemDB
  participant Project as SNOWFLAKE_EXAMPLE_CORTEX_USAGE
  participant Task as ServerlessTask
  participant ML as MLForecastModel
  participant App as StreamlitApp

  User->>Snowsight: SignIn
  Snowsight->>Auth: Authenticate
  Auth-->>Snowsight: SessionEstablished

  Snowsight->>RBAC: ValidateRoleAndPrivileges
  note over RBAC: Required for deployment\nIMPORTED_PRIVILEGES_on_SNOWFLAKE\nCREATE_DATABASE_on_ACCOUNT\nCREATE_SCHEMA_VIEW_TABLE_TASK

  alt DeployMonitoringAndAttribution
    Snowsight->>Project: CreateDatabaseAndSchema
    Snowsight->>Project: CreateViewsAndSnapshots
    Project->>SysDb: Read_ACCOUNT_USAGE
    SysDb-->>Project: UsageTelemetry
    Snowsight->>Task: CreateAndResumeTask
  end

  alt DeployForecastingModel
    Snowsight->>RBAC: Check_CREATE_SNOWFLAKE_ML_FORECAST
    RBAC-->>Snowsight: AllowedOrDenied
    alt Allowed
      Snowsight->>ML: CreateOrReplaceForecastModel
      ML-->>Snowsight: ModelReady
    else Denied
      note over ML: Deployment continues without model\nForecast view is empty placeholder
    end
  end

  alt DeployStreamlit
    Snowsight->>RBAC: Check_CREATE_STREAMLIT
    RBAC-->>Snowsight: Allowed
    Snowsight->>App: CreateStreamlitApp
  end

  User->>App: OpenApp
  App->>RBAC: EnforceCurrentRole
  RBAC-->>App: Allowed
  App->>Project: QueryViewsAndSnapshots
  Project-->>App: Results
  App-->>User: ChartsAndTables
```

## Component Descriptions
- **SnowflakeAuth**: Handles user authentication (SSO/MFA/password). Provides an authenticated Snowsight session.
- **SnowflakeRBAC**: Enforces permissions for deployment and usage (USAGE/SELECT on objects; CREATE privileges for deployment).
- **SNOWFLAKE_SystemDB**: Hosts `ACCOUNT_USAGE` sources; access requires `IMPORTED PRIVILEGES` on database `SNOWFLAKE`.
- **SNOWFLAKE_EXAMPLE_CORTEX_USAGE**: Project schema where views, snapshots, and the optional forecast model live.
- **StreamlitApp**: Runs queries under the user's current role; cannot bypass RBAC.

## Change History
See git history for changes to this diagram.
