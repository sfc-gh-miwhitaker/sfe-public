# Network Flow - Streamlit DR Replication Cost Calculator
Author: SE Community
Last Updated: 2025-12-08
Expires: 2026-04-10
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
Network interactions for the replication/DR cost calculator using Business Critical features.

```mermaid
graph TB
  subgraph External
    GitHub[GitHub Repository<br/>HTTPS :443]
  end
  subgraph "Snowflake Account"
    Snowsight[Snowsight UI<br/>HTTPS :443]
    GitRepo[@SNOWFLAKE_EXAMPLE.GIT_REPOS.REPLICATE_THIS_REPO<br/>Git Repository]
    StreamlitApp[Streamlit App<br/>Snowflake-hosted<br/>from Git repo clone]
    Tables[(PRICING_CURRENT)]
    DBMeta[(DB_METADATA)]
  end

  GitHub -->|FETCH via SFE_GIT_API_INTEGRATION| GitRepo
  GitRepo -->|loads app.py| StreamlitApp
  Snowsight -->|Launch| StreamlitApp
  StreamlitApp -->|Query| Tables
  StreamlitApp -->|Query| DBMeta
```

## Component Descriptions

### External Services
- **GitHub**: Source repository for deployment scripts and Streamlit app
  - Repository: `github.com/sfc-gh-miwhitaker/replicatethis`
  - Accessed via `SFE_GIT_API_INTEGRATION`

### Snowflake Components
- **Snowsight**: Entry point for deployment and app usage
  - Deploy: Run `deploy_all.sql` in Worksheets
  - Use: Launch Streamlit app from Streamlit section
- **Git Repository**: Native Snowflake Git integration
  - Path: `@SNOWFLAKE_EXAMPLE.GIT_REPOS.REPLICATE_THIS_REPO`
  - Provides source for Streamlit app (no manual uploads)
- **Streamlit App**: Auto-deployed from Git repository
  - Source location: `@...REPLICATE_THIS_REPO/branches/main/streamlit`
  - Main file: `app.py`
  - Runs inside Snowflake (Snowflake-hosted)
- **Tables/Views**: Pricing and metadata storage powering the UI
  - PRICING_CURRENT, DB_METADATA

## Change History
See `.cursor/DIAGRAM_CHANGELOG.md` for vhistory.
