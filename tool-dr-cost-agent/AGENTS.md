# DR Cost Agent (Snowflake Intelligence)

Snowflake Intelligence agent for estimating cross-region DR/replication costs with hybrid table awareness. This is the consolidated DR cost estimation tool -- there is no separate Streamlit version.

## Project Structure

- `deploy_standalone.sql` -- **Recommended**: paste into Snowsight, Run All, done (no Git required)
- `deploy.sql` -- Alternative: Git-integrated deployment via EXECUTE IMMEDIATE FROM
- `teardown.sql` -- Complete cleanup (works for either deploy method)
- `sql/` -- Modular SQL scripts (source of truth, used by both deploy paths)

## Snowflake Environment

- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `DR_COST_AGENT`
- Warehouse: `SFE_TOOLS_WH` (shared, XSmall, auto-suspend)
- Agent: `DR_COST_AGENT` (Snowflake Intelligence, display name "DR Cost Estimator")
- Semantic View: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST`
- Procedures: `COST_PROJECTION` (agent tool), `UPDATE_PRICING` (admin)

## Development Standards

- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects (`'TOOL: ... (Expires: YYYY-MM-DD)'`)
- Deploy: One-command via deploy_standalone.sql (preferred) or deploy.sql (Git-integrated)
- Roles: ACCOUNTADMIN for USAGE_VIEWER grant only, SYSADMIN for everything else
- Agent: `orchestration: auto` always -- never pin a specific model

## Customization Playbooks

### Add a New Cloud Region to Pricing

Insert 5 rows (one per service type) into `PRICING_CURRENT`. Use the `UPDATE_PRICING` procedure for individual rates, or direct SQL for bulk:

```sql
-- One at a time via procedure
CALL UPDATE_PRICING('DATA_TRANSFER', 'AWS', 'ca-central-1', 2.50);
CALL UPDATE_PRICING('REPLICATION_COMPUTE', 'AWS', 'ca-central-1', 1.00);
CALL UPDATE_PRICING('STORAGE_TB_MONTH', 'AWS', 'ca-central-1', 0.25);
CALL UPDATE_PRICING('SERVERLESS_MAINT', 'AWS', 'ca-central-1', 0.10);
CALL UPDATE_PRICING('HYBRID_STORAGE', 'AWS', 'ca-central-1', 0.06);
```

The agent and semantic view discover new regions automatically -- no code changes needed.

### Update an Existing Pricing Rate

```sql
CALL UPDATE_PRICING('DATA_TRANSFER', 'AWS', 'us-east-1', 2.75);
-- Returns: OK: DATA_TRANSFER rate for AWS/us-east-1 set to 2.75 by ADMIN_USER
```

Changes take effect immediately for all future projections.

### Change the Default Credit Price

The `COST_PROJECTION` procedure accepts `CREDIT_PRICE` as a parameter (default 3.50). The agent passes the user's value or defaults to 3.50. To change the default:

1. Edit `sql/04_procedures/01_cost_projection.sql`
2. The default is not hardcoded in the procedure -- it's in the agent instructions. Update the `cost_projection` tool description in `sql/06_agent/01_agent.sql` where it says `default 3.50`

### Add a New Cost Component

1. **Pricing**: Add service type rows to `sql/02_tables/01_pricing_current.sql`
2. **Procedure**: Add a new UNION ALL block in `sql/04_procedures/01_cost_projection.sql` (follow the existing pattern for "Secondary Storage" or "Serverless Maintenance")
3. **View** (if needed): If the component has its own ACCOUNT_USAGE source, create `sql/03_views/04_new_component.sql`
4. **Semantic view**: Add the new table/columns to `sql/05_semantic/01_semantic_view.sql`
5. **Agent instructions**: Add handling guidance to `sql/06_agent/01_agent.sql` if the component needs special treatment

### Adjust the Agent Personality or Instructions

Edit `sql/06_agent/01_agent.sql`. The YAML structure:

- `instructions.system` -- Core rules (data freshness, hybrid tables, disclaimers)
- `instructions.response` -- Output formatting preferences
- `instructions.orchestration` -- Step-by-step workflows the agent follows
- `instructions.sample_questions` -- Clickable conversation starters shown in SI

### Add a New Conversation Starter

Add to the `sample_questions` list in `sql/06_agent/01_agent.sql`:

```yaml
- question: "Your new question here"
  answer: "The agent's scripted first response"
```

Keep it under 8 total (SI displays best with 6-8).

### Connect to a BI Tool

Point Tableau, PowerBI, Sigma, or Hex at the views directly:

- `SNOWFLAKE_EXAMPLE.DR_COST_AGENT.DB_METADATA_V2` -- Database sizes with hybrid exclusion
- `SNOWFLAKE_EXAMPLE.DR_COST_AGENT.PRICING_CURRENT` -- All pricing rates
- `SNOWFLAKE_EXAMPLE.DR_COST_AGENT.REPLICATION_HISTORY` -- Historical replication usage

No joins needed for basic reporting. For cost projections, call the procedure:

```sql
CALL SNOWFLAKE_EXAMPLE.DR_COST_AGENT.COST_PROJECTION('ALL', 'AWS', 'us-west-2', 5.0, 1.0, 3.50);
```

## Extension Points (Safe to Modify)

| What | File | Safe Changes |
|------|------|-------------|
| Pricing rates | `sql/02_tables/01_pricing_current.sql` | Add rows, update rates |
| Database filter list | `sql/03_views/01_db_metadata_v2.sql` | Add databases to the NOT IN exclusion list |
| Cost formula | `sql/04_procedures/01_cost_projection.sql` | Add UNION ALL blocks for new components |
| Semantic model | `sql/05_semantic/01_semantic_view.sql` | Add tables, dimensions, facts, metrics |
| Agent behavior | `sql/06_agent/01_agent.sql` | Instructions, workflows, sample questions, tool descriptions |
| Access control | `sql/99_grants/01_grants.sql` | Grant to additional roles |

## When Helping with This Project

- Follow SFE naming conventions (`SFE_` prefix for account-level objects)
- Pricing data is seeded estimates -- always disclaim actual costs may vary
- Use `SNOWFLAKE.USAGE_VIEWER` database role (not blanket IMPORTED PRIVILEGES)
- Hybrid tables are SKIPPED during replication (BCR-1560-1582) -- the agent warns about this
- ACCOUNT_USAGE views lag up to 3 hours -- note data freshness in responses
- All new objects need `COMMENT = 'TOOL: ... (Expires: YYYY-MM-DD)'`
- The `deploy_standalone.sql` must be regenerated when modular SQL files change

## Helping New Users

If the user seems confused, asks basic questions like "what is this" or "how do I start", or appears unfamiliar with the tools:

1. **Greet them warmly** and explain this tool helps estimate DR replication costs using an AI agent
2. **Check deployment status** -- ask if they've run `deploy_standalone.sql` in Snowsight yet
3. **Guide step-by-step** -- if not deployed, walk them through:
   - Pasting `deploy_standalone.sql` into a Snowsight worksheet and clicking "Run All"
   - No Git integration or API integration needed for this path
4. **Suggest what to try** -- after deployment, direct them to Snowflake Intelligence to open the DR Cost Estimator agent
5. **If they want to customize** -- point them to the Customization Playbooks section above

## Related Projects
- [`guide-replication-workbook`](../guide-replication-workbook/) -- SQL runbooks for replication and failover setup
- [`tool-ai-spend-controls`](../tool-ai-spend-controls/) -- Broader Cortex cost governance platform
- [`tool-ai-spend-controls`](../tool-ai-spend-controls/) -- REST API-specific cost tracking
