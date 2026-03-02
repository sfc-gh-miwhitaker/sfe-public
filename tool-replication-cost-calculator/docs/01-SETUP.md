# Setup - Streamlit DR Replication Cost Calculator (Business Critical)

## Prerequisites

**This is a 100% Snowflake-native demo. No local setup required!**

- **Snowflake Edition**: Business Critical (required for replication/failover features)
- **Required Role**: `ACCOUNTADMIN` (for initial deployment only)
  - Creates Git API integration (requires ACCOUNTADMIN)
  - Script automatically switches to SYSADMIN for object creation
- **Network Access**: Snowflake must be able to fetch:
  - GitHub repository (via Git integration)

## Quick Start

1. Sign in to Snowsight
2. Ensure you have ACCOUNTADMIN role
3. Continue to `docs/02-DEPLOYMENT.md` to run `deploy_all.sql`

**That's it!** Everything deploys automatically.

## Security & Naming

### Role-Based Security (Best Practice)
- **ACCOUNTADMIN**: Creates Git API integration only
- **SYSADMIN**: Owns all database objects (warehouse, schema, tables, Streamlit app)
- **PUBLIC**: Granted read-only access (any user can run the demo)

### Object Naming
- **Schema**: `SNOWFLAKE_EXAMPLE.REPLICATION_CALC`
- **Warehouse**: `SFE_REPLICATION_CALC_WH` (XSmall, auto-suspend)
- **Streamlit App**: `REPLICATION_CALCULATOR`
- **Git Repository**: `SNOWFLAKE_EXAMPLE.GIT_REPOS.REPLICATE_THIS_REPO`

### Security Notes
- No credentials stored
- All external access is to GitHub (via Snowflake native Git integration)
- Minimal privilege grants (PUBLIC has SELECT/USAGE only)
- Streamlit app deploys directly from Git (no manual file uploads)
