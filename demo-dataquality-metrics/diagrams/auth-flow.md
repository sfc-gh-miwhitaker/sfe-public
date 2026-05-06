# Auth Flow - Data Quality Metrics & Reporting Demo

Author: SE Community
Last Updated: 2026-03-02
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

**Reference Implementation:** This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview

This diagram shows user authentication into Snowflake and role-based authorization for querying data and accessing the Streamlit app.

## Diagram

```mermaid
sequenceDiagram
  actor User
  participant Snowsight
  participant IdP as Identity Provider
  participant Snowflake
  User->>Snowsight: Sign in
  Snowsight->>IdP: SSO authentication
  IdP-->>Snowsight: Auth assertion
  Snowsight->>Snowflake: Start session with role
  User->>Snowsight: Run query or open Streamlit
  Snowsight->>Snowflake: Query with role permissions
  Snowflake-->>Snowsight: Results and dashboard data
```

## Component Descriptions

- Identity Provider: SSO authentication provider used for account access.
- Snowflake Session: Role-based session enforcing grants on schemas and objects.
- Streamlit Access: Streamlit app access controlled by Snowflake roles.

## Change History

See `.cursor/DIAGRAM_CHANGELOG.md` for version history.
