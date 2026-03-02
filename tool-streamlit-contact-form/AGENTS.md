# Contact Form (Streamlit in Snowflake)

Simple contact form built with Streamlit in Snowflake that writes submissions to a Snowflake table.

## Project Structure
- `deploy.sql` -- Single entry point (Run All in Snowsight)
- `teardown.sql` -- Complete cleanup

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: SFE_CONTACT_FORM
- Warehouse: SFE_TOOLS_WH

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy.sql
- Python: Use Snowpark DataFrame API for writes (not f-string SQL)

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use `get_active_session()` for Streamlit in Snowflake sessions
- Avoid f-string SQL construction; use parameterized queries or Snowpark writes
- All new objects need COMMENT = 'TOOL: ... (Expires: YYYY-MM-DD)'
