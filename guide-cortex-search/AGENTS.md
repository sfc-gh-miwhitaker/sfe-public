# Cortex Search Automation Patterns

Automation patterns for Cortex Search that go beyond official documentation: spec
export/recreation, parameterized deployment, E2E testing, and CI/CD pipelines.

## Project Structure
- `README.md` -- Overview and quick links
- `cortex_search_examples.sql` -- SQL patterns: create, describe, alter, drop, search, templates
- `cortex_search_e2e_test.sql` -- End-to-end test with SNOWFLAKE_PUBLIC_DATA_FREE
- `cortex-search-snowsight-guide.md` -- Snowsight UI walkthrough with export/redeploy

## Content Principles
- Fill gaps not covered by official Cortex Search documentation
- Runnable SQL examples using public datasets (no credentials needed)
- Parameterized deployment templates for CI/CD automation
- Snowsight UI guide for non-CLI users

## When Helping with This Project
- This is a guide, not a demo -- no deploy_all.sql, no expiration
- E2E test uses `SNOWFLAKE_PUBLIC_DATA_FREE` (no setup needed)
- `SEARCH_PREVIEW` is the function for testing search results
- Spec export uses `DESCRIBE CORTEX SEARCH SERVICE` (not DESC AGENT syntax)
- Parameterized templates use session variables for reusable deployment
- Filter operators in SEARCH_PREVIEW: `@eq`, `@contains`, `@gte`, `@lte`
- Some referenced files in README (Python SDK examples, agent integration) may not exist yet

## Related Projects
- [`demo-cortex-financial-agents`](../demo-cortex-financial-agents/) -- Cortex Search in the context of a full agent (RAG + Analyst)
