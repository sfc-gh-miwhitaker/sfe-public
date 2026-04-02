# Data Quality Metrics & Reporting Demo

Reference implementation for automated data quality monitoring and reporting using Snowflake native features.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `sql/` -- Individual SQL scripts (numbered)
- `streamlit/` -- Streamlit dashboard source
- `tools/` -- Demo script and utilities
- `diagrams/` -- Architecture diagrams (Mermaid)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: DATA_QUALITY
- Warehouse: SFE_DATA_QUALITY_WH

## Key Patterns
- Data Metric Functions (DMF) for automated quality checks
- Scheduled quality monitoring with TRIGGER_ON_CHANGES
- Dynamic Tables for quality trend aggregation
- Streamlit dashboard for visual quality reporting
- Object tagging (DATA_DOMAIN, DATA_SENSITIVITY, DATA_QUALITY_TIER)
- Tag-based masking policy on CONFIDENTIAL columns
- TAG_REFERENCES for governance reporting

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
- DMF schedule uses TRIGGER_ON_CHANGES (not cron)
- Allow 10 min after deploy for first DMF run to populate metrics
- Tags: DATA_DOMAIN, DATA_SENSITIVITY, DATA_QUALITY_TIER (with ALLOWED_VALUES)
- Tag-based masking: CONFIDENTIAL_STRING_MASK assigned to DATA_SENSITIVITY tag
- Teardown must UNSET MASKING POLICY from tag before dropping tags or policies

## Related Projects
- [`demo-api-quickbooks-medallion`](../demo-api-quickbooks-medallion/) -- Medallion architecture with DMFs and Cortex AI enrichment
- [`guide-csv-import`](../guide-csv-import/) -- Data loading fundamentals (prerequisite for data quality)
