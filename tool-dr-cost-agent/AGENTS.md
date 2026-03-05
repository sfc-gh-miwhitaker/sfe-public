# DR Cost Agent (Snowflake Intelligence)

Snowflake Intelligence agent for estimating cross-region DR/replication costs with hybrid table awareness.

## Project Structure
- `deploy.sql` -- Single entry point (Run All in Snowsight, uses Git integration)
- `teardown.sql` -- Complete cleanup
- `sql/` -- Numbered SQL scripts executed by deploy.sql

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: DR_COST_AGENT
- Warehouse: SFE_TOOLS_WH (shared)
- Agent: DR_COST_AGENT (Snowflake Intelligence)
- Semantic View: SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command via deploy.sql (Git-integrated, EXECUTE IMMEDIATE FROM)
- Roles: ACCOUNTADMIN for USAGE_VIEWER grant only, SYSADMIN for everything else

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Pricing data is seeded estimates; always disclaim actual costs may vary
- Use SNOWFLAKE.USAGE_VIEWER database role (not blanket IMPORTED PRIVILEGES)
- Hybrid tables are SKIPPED during replication (BCR-1560-1582) -- the agent warns about this
- ACCOUNT_USAGE views lag up to 3 hours -- note data freshness in responses
- Deploy via monorepo Git repo (no project-specific Git clone)
- All new objects need COMMENT = 'TOOL: ... (Expires: YYYY-MM-DD)'

## Helping New Users

If the user seems confused, asks basic questions like "what is this" or "how do I start", or appears unfamiliar with the tools:

1. **Greet them warmly** and explain this tool helps estimate DR replication costs using an AI agent
2. **Check deployment status** -- ask if they've run `deploy.sql` in Snowsight yet
3. **Guide step-by-step** -- if not deployed, walk them through:
   - Running `shared/sql/00_shared_setup.sql` first (one-time shared infra)
   - Then pasting `deploy.sql` into a Snowsight worksheet and clicking "Run All"
4. **Suggest what to try** -- after deployment, direct them to Snowflake Intelligence to open the DR Cost Estimator agent
