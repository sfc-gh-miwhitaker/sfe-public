# GitHub-Powered Project Tooling for Cortex Code

Example project standards that Cortex Code reads automatically -- in CLI (from your cloned repo) and in Snowsight (from a Git-connected workspace). Fork this file and customize it for your team.

## Project Structure
- `deploy_all.sql` -- Creates sample schema and tables in Snowflake (Run All in Snowsight)
- `teardown_all.sql` -- Removes all demo objects
- `sql/` -- Individual setup scripts
- `docs/` -- Three-act walkthrough: project tooling, GitHub team management, Intune enterprise
- `reference/` -- MCP configs and managed-settings templates
- `diagrams/` -- Mermaid architecture diagrams

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: COCO_GOVERNANCE_GITHUB
- Warehouse: SFE_COCO_GOVERNANCE_GITHUB_WH
- Tables: CUSTOMERS, ORDERS, PRODUCTS (sample data for testing standards)

## SQL Standards

### Query Quality
- **No SELECT * in production code** -- always list columns explicitly
- **Sargable predicates only** -- no functions wrapping columns in WHERE clauses
  - Wrong: `WHERE YEAR(created_at) = 2025`
  - Right: `WHERE created_at >= '2025-01-01' AND created_at < '2026-01-01'`
- **Use QUALIFY for window function filtering** -- not subqueries or CTEs that re-filter
  - Wrong: `SELECT * FROM (SELECT *, ROW_NUMBER() OVER(...) AS rn FROM t) WHERE rn = 1`
  - Right: `SELECT col1, col2 FROM t QUALIFY ROW_NUMBER() OVER(...) = 1`
- **Join keys must match types** -- no implicit casts between VARCHAR and NUMBER

### Naming Conventions
- Warehouses: `SFE_<PROJECT>_WH`
- Schemas: descriptive uppercase, underscores (e.g., `COCO_GOVERNANCE_GITHUB`)
- Tables: `RAW_<entity>` for landing, `STG_<entity>` for staging, `<ENTITY>` for serving
- All objects must include `COMMENT = 'DEMO: <project> - <purpose> (Expires: YYYY-MM-DD)'`

### Operational Discipline
- Set `STATEMENT_TIMEOUT_IN_SECONDS` on warehouses to kill runaway queries
- Use `CREATE ... IF NOT EXISTS` for idempotent deployment
- Never hardcode credentials -- use Snowflake secrets or environment variables

## Security Rules
- Never commit API keys, tokens, passwords, or `.env` files
- Never include Snowflake account identifiers in code or output
- Use environment variables or Snowflake secrets for all credentials
- Attribution: `Pair-programmed by SE Community + Cortex Code` (never personal names)

## When Helping with This Project
- This project demonstrates how AGENTS.md and skills deliver consistent standards across CLI and Snowsight
- The demo has THREE audiences: individual developers (Act 1), team leads (Act 2), IT admins (Act 3)
- Sample tables exist for testing -- write realistic queries against CUSTOMERS, ORDERS, PRODUCTS
- Reference configs in `reference/` include BOTH 1Password and PAT patterns for GitHub MCP
- If adding new SQL, follow the naming and comment conventions above
- Keep deploy_all.sql as the single Snowsight entry point

## Helping New Users

If the user seems confused or asks "what is this" or "how do I start":

1. Explain: "This project shows how the same AGENTS.md file gives Cortex Code consistent standards whether you use the CLI or Snowsight."
2. Point them to `docs/01-PROJECT-TOOLING.md` for the step-by-step walkthrough
3. If they want to try it: clone this repo and run `cortex` in this directory, or create a Snowsight workspace from the Git repo

## Related Projects
- [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) -- Install and connect (prerequisite)
- [`guide-coco-governance-general`](../guide-coco-governance-general/) -- Full AI coding governance workshop
- [`guide-agent-skills`](../guide-agent-skills/) -- Skills architecture and context budget management
- [`demo-campaign-engine`](../demo-campaign-engine/) -- Hands-on agent-building workshop (GUIDED_BUILD)
