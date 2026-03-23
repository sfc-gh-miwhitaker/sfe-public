# Cortex Agent Cost

Streamlit in Snowflake tool for granular cost reporting and forecasting of Cortex Agent and Snowflake Intelligence usage, with per-model token and credit breakdowns.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Modular SQL scripts (numbered 01-04)
- `streamlit/` -- Multi-page Streamlit dashboard
- `.claude/skills/` -- Project-specific AI skill

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CORTEX_AGENT_COST
- Warehouse: SFE_CORTEX_AGENT_COST_WH
- Streamlit: CORTEX_AGENT_COST_APP

## Key Concepts
- Queries `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY` and `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY`
- Flattens `TOKENS_GRANULAR` and `CREDITS_GRANULAR` arrays via triple LATERAL FLATTEN
- Warehouse runtime only (no Cortex Agent API calls from SiS)
- ACCOUNT_USAGE views lag up to 45 minutes

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
- All new objects need COMMENT = 'TOOL: ... (Expires: 2026-04-22)'

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql as the single entry point
- The `svc.key != 'start_time'` filter is required when flattening TOKENS_GRANULAR/CREDITS_GRANULAR
- Views depend on each other: detail → combined → granular → summary. Maintain creation order.

## Helping New Users

If the user seems confused, asks basic questions like "what is this" or "how do I start", or appears unfamiliar with the tools:

1. **Greet them warmly** and explain this tool tracks Cortex Agent costs with per-model breakdowns
2. **Check deployment status** -- ask if they've run `deploy_all.sql` in Snowsight yet
3. **Guide step-by-step** -- if not deployed, walk them through:
   - Opening Snowsight (the Snowflake web interface)
   - Creating a new SQL worksheet
   - Pasting the contents of `deploy_all.sql`
   - Clicking "Run All" (the play button with two arrows)
4. **Suggest what to try** -- after deployment, open the Streamlit app from Projects > Streamlit
