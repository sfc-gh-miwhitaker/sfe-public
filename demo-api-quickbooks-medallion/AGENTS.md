# QuickBooks API Medallion Architecture Demo

Pull accounting data from QuickBooks Online into Snowflake using native features with medallion architecture, Cortex AI enrichment, and Data Metric Functions for quality monitoring.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered by layer)
- `diagrams/` -- Architecture diagrams (Mermaid)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: QB_API
- Warehouse: SFE_QB_API_WH

## Key Patterns
- External Access Integration for QuickBooks Online API (OAuth 2.0)
- Medallion architecture: Bronze (raw JSON) -> Silver (typed) -> Gold (aggregated)
- Cortex AI enrichment (AI_COMPLETE for invoice note analysis)
- Data Metric Functions for continuous quality monitoring
- Sample data mode (no QBO credentials required)

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
- Naming: SFE_ prefix for account-level objects only; project objects scoped by schema

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql as the single entry point
- All new objects need COMMENT = 'DEMO: ... (Expires: 2026-05-01)'
- Two modes: sample data (no creds) and live API (OAuth required)
- Bronze layer stores raw JSON in VARIANT columns

## Related Projects
- [`demo-dataquality-metrics`](../demo-dataquality-metrics/) -- Deeper data quality patterns with DMFs, tagging, and masking
- [`tool-api-data-fetcher`](../tool-api-data-fetcher/) -- Simpler external access pattern (generic REST API)
- [`tool-secrets-rotation-aws`](../tool-secrets-rotation-aws/) -- Credential rotation for API secrets
- [`guide-csv-import`](../guide-csv-import/) -- Simpler data loading starting point
