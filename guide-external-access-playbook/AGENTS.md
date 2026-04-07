# External Access Playbook

Unified patterns for calling external APIs from Snowflake: network rules, External Access Integrations, secrets management, OAuth flows, and production hardening. Extracted from working demos and tools in this repository.

## Project Structure

- `README.md` -- Complete guide (5 parts + decision tree)

## Content Principles

- Extract patterns from tool-api-data-fetcher and demo-api-quickbooks-medallion
- Two progression levels: simple (public API, no auth) and OAuth (full stack)
- Generic SQL examples using placeholder names
- Production hardening section covers rotation, scheduling, monitoring

## When Helping with This Project

- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects to create
- All SQL is embedded in README.md (no separate .sql files)
- Network rules require CREATE NETWORK RULE privilege (ACCOUNTADMIN, SECURITYADMIN, or schema owner)
- EAI creation requires ACCOUNTADMIN or CREATE INTEGRATION privilege
- OAuth secrets use `_snowflake.get_oauth_access_token()` at runtime
- Always include both API hosts and token endpoints in network rules for OAuth flows
- Never hardcode credentials in stored procedure code

## Related Projects

- [`tool-api-data-fetcher`](../tool-api-data-fetcher/) -- Simplest pattern (public API, no auth)
- [`demo-api-quickbooks-medallion`](../demo-api-quickbooks-medallion/) -- Full OAuth with medallion architecture
- [`tool-secrets-rotation-aws`](../tool-secrets-rotation-aws/) -- Credential rotation patterns
- [`demo-cortex-openai-enrichment`](../demo-cortex-openai-enrichment/) -- Cortex AI enrichment of API data
