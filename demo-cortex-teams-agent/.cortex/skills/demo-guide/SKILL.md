---
name: teams-agent-uni-guide
description: "Guide for working with the Cortex Agents Teams & M365 Copilot demo project."
---

# Teams Agent Uni - Project Guide

## When to Use
- Working with this demo project
- Modifying the joke agent or adding new agents
- Updating the Entra ID or security integration setup
- Extending to production analytics patterns

## Key Patterns

### Agent Creation
Agents are created via `CREATE AGENT` DDL with a YAML specification:
```sql
CREATE OR REPLACE AGENT <name>
  FROM SPECIFICATION $$ <yaml> $$;
```
Tool types in YAML: `custom_tool`, `cortex_analyst_text_to_sql`, `cortex_search`.

### LLM Function Calls
Use `AI_COMPLETE` (not legacy `SNOWFLAKE.CORTEX.COMPLETE`):
```sql
SELECT AI_COMPLETE('model-name', [messages], {options});
```
Guardrails is a boolean: `'guardrails': true`.

### Authentication
External OAuth with Microsoft Entra ID requires consent for TWO applications:
1. OAuth Resource: `5a840489-78db-4a42-8772-47be9d833efe`
2. OAuth Client: `bfdfa2a2-bce5-4aee-ad3d-41ef70eb5086`

### Naming
- Schema: `SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI`
- Warehouse: `SFE_TEAMS_AGENT_UNI_WH`
- Agent: `JOKE_ASSISTANT`
- Function: `GENERATE_SAFE_JOKE`
