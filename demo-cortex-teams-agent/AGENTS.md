# Snowflake Cortex Agents for Microsoft Teams & M365 Copilot

Reference implementation showing how to deploy a Cortex Agent to Microsoft Teams
and Microsoft 365 Copilot using a joke-generator demo with content safety guardrails.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered)
- `docs/` -- Step-by-step guides for Entra ID, security integration, Teams install
- `diagrams/` -- Architecture diagrams (Mermaid)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: TEAMS_AGENT_UNI
- Warehouse: SFE_TEAMS_AGENT_UNI_WH
- Agent: JOKE_ASSISTANT (CREATE AGENT DDL)
- Function: GENERATE_SAFE_JOKE (uses AI_COMPLETE with Cortex Guard)

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
- Agent: Use CREATE AGENT DDL with YAML specification
- LLM calls: Use AI_COMPLETE (not legacy SNOWFLAKE.CORTEX.COMPLETE)
- Guardrails: Boolean `true` (not the old object syntax)

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql as the single entry point
- All new objects need COMMENT = 'DEMO: ... (Expires: 2026-05-01)'
- Agent tool type is `custom_tool` in YAML spec, `generic` in REST API
- Security integration requires TWO Entra ID app consents (Resource + Client)
- SHOW AGENTS (not SHOW CORTEX AGENTS) for listing agents
- Network policies ARE supported (March 2026); Private Link is NOT supported
- Default user role must not be an admin role (ACCOUNTADMIN, SECURITYADMIN)
- Each Microsoft user must map to exactly one Snowflake user (strict 1:1)
- Custom branding available for Teams app (1.2.0+) via Teams Admin Center
