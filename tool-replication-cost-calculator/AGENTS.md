# Replication Cost Calculator

Snowflake-native Streamlit app for estimating DR replication costs using Business Critical pricing.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight, uses Git integration)
- `streamlit/` -- Streamlit app source
- `docs/` -- Numbered documentation (01-SETUP through 05-ADMIN)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: REPLICATION_CALC
- Warehouse: SFE_REPLICATION_CALC_WH

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command via deploy_all.sql (Git-integrated)
- Roles: ACCOUNTADMIN for API integration only, SYSADMIN for everything else

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Pricing data is seeded estimates; always disclaim actual costs may vary
- Use SNOWFLAKE.USAGE_VIEWER database role (not blanket IMPORTED PRIVILEGES)
- Streamlit deployed from Git repository (no manual uploads)
- All new objects need COMMENT = 'DEMO: ... (Expires: YYYY-MM-DD)'
