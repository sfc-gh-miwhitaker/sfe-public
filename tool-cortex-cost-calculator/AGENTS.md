# Cortex Cost Calculator

Cortex spend attribution dashboard with 12-month forecasting via Streamlit in Snowflake.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight, uses Git integration)
- `sql/01_deployment/` -- Monitoring views deployment
- `sql/02_utilities/` -- Export utilities
- `sql/99_cleanup/` -- Complete cleanup
- `streamlit/cortex_cost_calculator/` -- Streamlit app

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CORTEX_USAGE
- Git Repository: SFE_CORTEX_TRAIL_REPO (in GIT_REPOS schema)

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command via deploy_all.sql (Git-integrated)
- Views: 22 views covering monitoring + attribution + forecast

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- SSOT for expiration is line 7 of deploy_all.sql
- ACCOUNT_USAGE has 45min-3hr latency (platform constraint)
- Streamlit uses `ADD LIVE VERSION FROM LAST` to avoid manual activation
- All new objects need COMMENT = 'DEMO: ... (Expires: YYYY-MM-DD)'
