# Customization & Production Handoff

This demo proves the architecture with a joke generator. The **same pattern**
powers enterprise analytics. This guide covers tweaking the demo and deploying
real agents.

---

## Tweak the Demo

### Change the LLM Model

```sql
CREATE OR REPLACE FUNCTION GENERATE_SAFE_JOKE(subject VARCHAR)
RETURNS VARCHAR LANGUAGE SQL AS
$$
  SELECT AI_COMPLETE(
    'llama4-maverick',  -- or: openai-gpt-4.1, claude-4-sonnet, llama3.3-70b
    [ ... same messages ... ],
    {'guardrails': true, 'temperature': 0.7, 'max_tokens': 150}
  ):choices[0]:messages::STRING
$$;
```

Available models (March 2026):
`claude-4-opus`, `claude-4-sonnet`, `openai-gpt-4.1`, `openai-o4-mini`,
`llama4-maverick`, `llama4-scout`, `llama3.3-70b`, `mistral-large2`,
`deepseek-r1`, `snowflake-llama-3.3-70b`

### Adjust Creativity

`'temperature': 0.9` = more creative | `'temperature': 0.3` = more consistent

### Cross-Region Inference

To access the full model set across regions:

```sql
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

---

## Production: Cortex Analyst Agent

Replace the joke function with a Cortex Analyst tool backed by a semantic view:

```sql
CREATE OR REPLACE AGENT SALES_ANALYST
    COMMENT = 'Production sales analytics agent for Teams'
    PROFILE = '{"display_name": "Sales Analyst", "color": "green"}'
    FROM SPECIFICATION
    $$
    models:
      orchestration: auto

    orchestration:
      budget:
        seconds: 60
        tokens: 16000

    instructions:
      system: >
        You are a revenue operations analyst. Answer questions about sales data
        using the configured semantic view. Respect RBAC. Disclose data freshness.
      response: >
        Lead with the requested metric, then supporting context. Cite the data source.
      orchestration: >
        Plan your approach before querying. Prefer a single SQL statement per prompt.
      sample_questions:
        - question: "What were Q4 revenues?"
        - question: "Show monthly trend by region"
        - question: "Which products grew fastest this year?"

    tools:
      - tool_spec:
          type: "cortex_analyst_text_to_sql"
          name: "sales_analyst"
          description: >
            Structured analytics over the sales semantic view. Converts natural
            language to SQL queries against revenue, product, and regional data.

    tool_resources:
      sales_analyst:
        semantic_view: "DB.SCHEMA.SV_SALES_OVERVIEW"
    $$;
```

### Grant Access

```sql
CREATE ROLE IF NOT EXISTS SALES_AGENT_ROLE
    COMMENT = 'Teams-facing role for sales analytics agent';

GRANT USAGE ON DATABASE DB TO ROLE SALES_AGENT_ROLE;
GRANT USAGE ON SCHEMA DB.SCHEMA TO ROLE SALES_AGENT_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA DB.SCHEMA TO ROLE SALES_AGENT_ROLE;
GRANT USAGE ON WAREHOUSE SFE_TEAMS_AGENT_UNI_WH TO ROLE SALES_AGENT_ROLE;
GRANT USAGE ON AGENT SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.SALES_ANALYST
    TO ROLE SALES_AGENT_ROLE;

GRANT ROLE SALES_AGENT_ROLE TO USER <sales_manager>;
ALTER USER <sales_manager> SET DEFAULT_SECONDARY_ROLES = ('ALL');
```

---

## Production: Cortex Search Agent (Unstructured Data)

```sql
CREATE OR REPLACE AGENT POLICY_ASSISTANT
    COMMENT = 'Company policy search agent'
    FROM SPECIFICATION
    $$
    models:
      orchestration: auto
    instructions:
      system: "You help employees find company policies."
    tools:
      - tool_spec:
          type: "cortex_search"
          name: "policy_search"
          description: "Search company policy documents"
    tool_resources:
      policy_search:
        name: "MY_DB.MY_SCHEMA.POLICY_SEARCH_SERVICE"
        max_results: "5"
    $$;
```

---

## Production: Multi-Tool Agent

Combine Cortex Analyst + Cortex Search + custom tools:

```sql
CREATE OR REPLACE AGENT BUSINESS_ASSISTANT
    FROM SPECIFICATION
    $$
    models:
      orchestration: auto
    instructions:
      system: "You help with business questions."
      orchestration: "Use sales_data for revenue questions, policy_search for policy questions."
    tools:
      - tool_spec:
          type: "cortex_analyst_text_to_sql"
          name: "sales_data"
          description: "Structured sales analytics"
      - tool_spec:
          type: "cortex_search"
          name: "policy_search"
          description: "Company policy documents"
    tool_resources:
      sales_data:
        semantic_view: "DB.SCHEMA.SV_SALES"
      policy_search:
        name: "DB.SCHEMA.POLICY_SEARCH"
        max_results: "5"
    $$;
```

---

## Agents Work Across All Interfaces

Agents created here work identically across:
- **Snowflake Intelligence** (Snowsight)
- **Microsoft Teams** (bot chat)
- **Microsoft 365 Copilot** (conversational workflow)

Changes to instructions, tools, or permissions reflect across all three immediately.

---

## Customer Validation Checklist

- [ ] Agent responds correctly to sample questions
- [ ] RBAC enforced (users see only their permitted data)
- [ ] Row-level security policies respected
- [ ] Data masking policies applied
- [ ] Response time acceptable (< 10 seconds for typical queries)
- [ ] Cortex Guard blocks unsafe prompts
- [ ] Audit trail visible in QUERY_HISTORY
- [ ] Users can switch between agents in Teams

---

## Monitoring

```sql
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE AGENT_NAME = 'SALES_ANALYST'
ORDER BY START_TIME DESC;

SELECT DATE_TRUNC('day', start_time) AS usage_date,
       SUM(credits_used) AS daily_credits,
       COUNT(*) AS query_count
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'SFE_TEAMS_AGENT_UNI_WH'
GROUP BY usage_date
ORDER BY usage_date DESC;
```

---

## Reference

- [Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [CREATE AGENT](https://docs.snowflake.com/en/sql-reference/sql/create-agent)
- [AI_COMPLETE](https://docs.snowflake.com/en/sql-reference/functions/ai_complete)
- [Build Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence/build-agents)
- [Best Practices for Building Cortex Agents](https://www.snowflake.com/en/developers/guides/best-practices-to-building-cortex-agents/)
