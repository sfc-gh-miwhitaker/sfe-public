# Step 7: Cortex Intelligence Agent

## AI-Pair Technique: Teach the AI About Your Data

The semantic view is where you teach Snowflake's Intelligence engine what your data *means* -- not just what columns exist, but what they represent, how they relate, and what questions they answer. Rich COMMENT metadata and correct clause ordering make the difference between an agent that understands "show me high-value players" and one that returns garbage.

## Before You Start

- [ ] Step 6 complete: Streamlit dashboard is deployed or ready
- [ ] All tables, Dynamic Tables, and procedures from Steps 1-5 exist
- [ ] AGENTS.md is updated to v3 (from Step 5)
- [ ] Create the shared semantic models schema if it doesn't exist:

```sql
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared semantic views for Cortex Intelligence agents';
```

## The Prompt

Paste this into your AI tool:

> "Create a Cortex Intelligence Agent with a semantic view over player features, campaigns, and campaign responses. The agent should answer natural-language questions about campaign performance, player behavior, and audience segments."

## What to Tell the AI (AGENTS.md v4 -- Final)

After this step, replace your `AGENTS.md` with the final version. This is the same content as the project's committed [AGENTS.md](../AGENTS.md):

```markdown
# Casino Campaign Recommendation Engine

Campaign recommendation engine for casino operators with ML audience targeting and vector-based player lookalike matching.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered)
- `streamlit/` -- Streamlit dashboard source

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CAMPAIGN_ENGINE
- Warehouse: SFE_CAMPAIGN_ENGINE_WH

## Key Patterns
- Dynamic Tables with TARGET_LAG for automated feature engineering refresh
- VECTOR(FLOAT, 16) data type for player behavior embeddings
- VECTOR_COSINE_SIMILARITY for lookalike player matching
- SNOWFLAKE.ML.CLASSIFICATION for campaign audience scoring
- SNOWFLAKE.CORTEX.COMPLETE for campaign recommendation generation
- Semantic views: FACTS before DIMENSIONS (clause order matters)
- CREATE AGENT with YAML spec; tool type `cortex_analyst_text_to_sql`; semantic view in `tool_resources`
- Python stored procedures for vector aggregation logic

## Development Standards
- Naming: RAW_ prefix for staging tables; SFE_ prefix for account-level objects only
- IDs: INTEGER primary keys (GENERATOR/UNIFORM for synthetic data)
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT = 'DEMO: <description> (Expires: 2026-05-01)' on all objects
- Constraints: PRIMARY KEY on every table, FOREIGN KEY where applicable
- Deploy: One-command deployment via deploy_all.sql

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql as the single entry point
- All new objects need COMMENT = 'DEMO: ... (Expires: 2026-05-01)'
- Dynamic Tables use TARGET_LAG = '1 hour' for demo cadence
- VECTOR columns are VECTOR(FLOAT, 16) -- 16 behavioral features
- ML models are created with SNOWFLAKE.ML.CLASSIFICATION
- Streamlit uses FROM with Git repo stage, not ROOT_LOCATION
```

Key additions in v4: semantic view clause order rule (FACTS before DIMENSIONS), CREATE AGENT YAML syntax, Streamlit deployment pattern, and a full "When Helping with This Project" section. This is the definitive version -- any AI tool that reads this file can work on the project correctly.

## Validate Your Work

```sql
-- Semantic view should exist in the shared schema
SHOW SEMANTIC VIEWS LIKE 'SV_CAMPAIGN%' IN SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS;

-- Agent should exist
SHOW AGENTS LIKE 'CAMPAIGN%' IN SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;

-- Test the agent in Snowsight:
-- Go to Snowflake Intelligence and ask:
-- "Which campaign type has the highest response rate?"
-- "What is the average daily wagering for Diamond tier players?"
```

Expected: Semantic view exists with FACTS, DIMENSIONS, and METRICS defined. Agent exists and responds to natural language questions about campaign data.

## Common Mistake

**DIMENSIONS before FACTS** (clause order)

What goes wrong: The AI generates a semantic view that looks syntactically reasonable:

```sql
-- WRONG: This will fail
CREATE SEMANTIC VIEW ...
  TABLES (...)
  RELATIONSHIPS (...)
  DIMENSIONS (...)   -- Snowflake requires FACTS first
  FACTS (...)
  METRICS (...)
```

Snowflake's parser rejects this with an unhelpful error message that doesn't mention clause order. This trips up even experienced Snowflake users because the requirement is counterintuitive -- you'd expect DIMENSIONS to come before FACTS (they describe the grouping axes, after all).

The fix: The correct order is TABLES, RELATIONSHIPS, FACTS, DIMENSIONS, METRICS. If your AI got this wrong, either:
1. Rearrange the clauses manually
2. Or tell the AI: "Snowflake semantic views require FACTS before DIMENSIONS. Reorder the clauses."

This is exactly the kind of platform quirk that belongs in AGENTS.md. The v4 update includes "Semantic views: FACTS before DIMENSIONS (clause order matters)" so the AI gets it right on every future attempt.

**Missing CREATE AGENT syntax?** The AI may generate the older `CREATE CORTEX AGENT` syntax or a JSON-based spec. The current syntax is:

```sql
CREATE OR REPLACE AGENT agent_name
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  instructions:
    response: >-
      ...
  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: tool_name
  tool_resources:
    tool_name:
      semantic_view: FULLY.QUALIFIED.SEMANTIC_VIEW_NAME
  $$;
```

If the AI used old syntax, follow up with: "Use CREATE AGENT with a YAML specification. The tool type is cortex_analyst_text_to_sql and the semantic view goes in tool_resources."

## What Just Happened

The AI produced two artifacts that make your data queryable in natural language:

1. **Semantic View** (`SV_CAMPAIGN_ENGINE_ANALYTICS`) -- Defines the business meaning of your data:
   - **TABLES** with PRIMARY KEY and SYNONYMS ("players" = player_features)
   - **RELATIONSHIPS** (campaign_responses references both players and campaigns)
   - **FACTS** -- measurable values (avg_daily_wager, lifetime_wagered, redemption_amount)
   - **DIMENSIONS** -- grouping axes (loyalty_tier, campaign_type, responded)
   - **METRICS** -- pre-computed aggregations (response_rate, player_count, total_redemption)
   - **COMMENT on every element** -- This is what makes the agent smart. "Average amount wagered per active day in dollars" helps the agent map "high rollers" to `avg_daily_wager`.

2. **Intelligence Agent** (`CAMPAIGN_ANALYTICS_AGENT`) -- YAML-specified agent that:
   - Uses `cortex_analyst_text_to_sql` to convert questions to SQL
   - References the semantic view for schema understanding
   - Includes sample questions for the agent's landing page
   - Includes `data_to_chart` tool for automatic visualization

Key patterns to notice:

- **SYNONYMS** -- "players", "player behavior", "player metrics" all map to the same table. Without these, the agent only understands exact table names.
- **COMMENT granularity** -- Every fact, dimension, and metric has a plain-English comment. The agent uses these to disambiguate "wagering" (avg_daily_wager vs. lifetime_wagered vs. avg_bet_size).
- **Metrics vs. Facts** -- `response_rate` is a METRIC (computed aggregation), not a FACT (raw column). This distinction helps the agent generate correct SQL with proper GROUP BY.

## If Something Went Wrong

**Semantic view creation fails with a parse error?** Check clause order: TABLES, RELATIONSHIPS, FACTS, DIMENSIONS, METRICS. See the Common Mistake section above.

**Agent returns wrong numbers?** The COMMENT metadata may be misleading. If "average wagering" returns lifetime totals, check that the FACT comment says "per active day" and the METRIC formula uses AVG, not SUM.

**Agent can't answer questions about a specific column?** Add it as a FACT or DIMENSION in the semantic view. Only columns explicitly declared in the semantic view are accessible to the agent.

## What Was Generated

- Semantic view with dimensions, facts, and metrics spanning 3 tables
- Intelligence Agent with YAML specification and sample questions
- Agent registration with Snowflake Intelligence

## Reference Implementation

Compare your AI's output to:
- [sql/05_cortex/01_create_semantic_view.sql](../sql/05_cortex/01_create_semantic_view.sql)
- [sql/05_cortex/02_create_agent.sql](../sql/05_cortex/02_create_agent.sql)
