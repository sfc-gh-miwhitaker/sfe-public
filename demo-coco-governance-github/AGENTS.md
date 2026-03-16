# Governed GitHub Integration for Cortex Code

Demonstrates the progressive unlock pattern: GitHub MCP integration is gated by governance configuration.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered)
- `docs/` -- Step-by-step governance-then-GitHub walkthrough
- `reference/` -- managed-settings and mcp.json templates
- `diagrams/` -- Architecture diagrams (Mermaid)
- `future/` -- Copilot-to-Cortex bridge architecture (placeholder)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: COCO_GOVERNANCE_GITHUB
- Warehouse: SFE_COCO_GOVERNANCE_GITHUB_WH
- Agent: GOVERNANCE_ADVISOR
- Function: VALIDATE_GOVERNANCE_POLICY
- Tables: GOVERNANCE_POLICY_LOG, MCP_CONNECTION_AUDIT

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
- Agent: Use CREATE AGENT DDL with YAML specification
- LLM calls: Use AI_COMPLETE (not legacy SNOWFLAKE.CORTEX.COMPLETE)

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql as the single entry point
- All new objects need COMMENT = 'DEMO: coco-governance-github ... (Expires: 2026-04-15)'
- This project has TWO audiences: IT admins (governance) and developers (GitHub integration)
- Reference templates always include BOTH 1Password and PAT patterns
- managed-settings.json examples must match the official Snowflake docs schema
- The progressive unlock concept is the core thesis: governance BEFORE connection
- SHOW AGENTS (not SHOW CORTEX AGENTS) for listing agents

## Helping New Users

If the user seems confused, asks basic questions like "what is this" or "how do I start", or appears unfamiliar with the tools:

1. **Greet them warmly** and explain: "This project teaches you to safely connect GitHub to your AI coding tools by setting up governance controls first."
2. **Check deployment status** -- ask if they've run `deploy_all.sql` in Snowsight yet
3. **Guide step-by-step** -- if not deployed, walk them through:
   - Opening Snowsight (the Snowflake web interface)
   - Creating a new SQL worksheet
   - Pasting the contents of `deploy_all.sql`
   - Clicking "Run All" (the play button with two arrows)
4. **Suggest what to try** -- after deployment, suggest asking the Governance Advisor: "Am I ready to enable GitHub?"
