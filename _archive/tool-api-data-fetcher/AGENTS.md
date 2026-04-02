# API Data Fetcher

Python stored procedure that fetches data from a public REST API and stores it in Snowflake via External Access Integration.

## Project Structure
- `deploy.sql` -- Single entry point (Run All in Snowsight)
- `teardown.sql` -- Complete cleanup

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: SFE_API_FETCHER
- Warehouse: SFE_TOOLS_WH

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy.sql
- Python: Use Snowpark DataFrame API for writes (not f-string SQL)

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- External Access Integration requires ACCOUNTADMIN to create
- Network Rules define allowed egress destinations
- All new objects need COMMENT = 'TOOL: ... (Expires: YYYY-MM-DD)'

## Related Projects
- [`demo-api-quickbooks-medallion`](../demo-api-quickbooks-medallion/) -- Full OAuth external access with medallion architecture
- [`tool-secrets-rotation-aws`](../tool-secrets-rotation-aws/) -- Credential management for API secrets
- [`demo-cortex-openai-enrichment`](../demo-cortex-openai-enrichment/) -- External API calls with Cortex AI enrichment
