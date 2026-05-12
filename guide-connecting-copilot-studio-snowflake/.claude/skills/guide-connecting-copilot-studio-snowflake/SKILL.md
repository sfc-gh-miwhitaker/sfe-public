---
name: guide-connecting-copilot-studio-snowflake
description: "Connect Microsoft Copilot Studio to Snowflake via Knowledge Source, Cortex Analyst Agent Flow, or MCP Server with Cortex Agent. Use when: Copilot Studio Snowflake, Power Platform Snowflake, MCP copilot, Dataverse connector Snowflake, Cortex Agent MCP, Copilot delegation, knowledge source Snowflake."
---

# guide-connecting-copilot-studio-snowflake

## Purpose

Four-pattern guide for connecting Microsoft Copilot Studio to Snowflake data. Covers Knowledge Source (no-code), Cortex Analyst via Agent Flow (semantic-grounded), and MCP Server with Cortex Agent (full delegation). Educates on when each pattern is appropriate and provides a decision framework backed by real evaluation data.

## Architecture

```
Pattern A: Knowledge Source (no-code, direct table query)
  Copilot Studio → Snowflake Connector → Tables

Pattern B: Cortex Analyst via Agent Flow
  Copilot Studio → Power Automate Agent Flow → Stored Procedure → Cortex Analyst → Semantic Model → Tables

Pattern C: MCP Server + Cortex Agent (recommended)
  Copilot Studio → MCP Connector → Snowflake MCP Server → Cortex Agent → (Analyst + Search + Custom Tools)
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Landing page — decision framework, 4-pattern comparison, governance table |
| `knowledge-source.md` | Pattern A: No-code quick start with Snowflake as Knowledge Source |
| `cortex-analyst-connector.md` | Pattern B: Cortex Analyst via stored procedure + Agent Flow |
| `mcp-server.md` | Pattern C: MCP Server + Cortex Agent (production recommendation) |
| `AGENTS.md` | Project context for AI assistants |

## Extension Playbook: Adding a New Tool to the MCP Server

**To add a new Cortex tool (e.g., a custom UDF) to an existing Pattern C setup:**

1. Create the UDF/procedure in Snowflake and grant USAGE to the MCP role
2. Update the MCP Server specification to include the new tool:
   ```sql
   CREATE OR REPLACE MCP SERVER <DB>.<SCHEMA>.COPILOT_MCP_SERVER
     FROM SPECIFICATION $$
       tools:
         - name: "copilot-agent"
           type: "CORTEX_AGENT_RUN"
           identifier: "<DB>.<SCHEMA>.COPILOT_AGENT"
           ...
         - name: "my-new-tool"
           type: "GENERIC"
           identifier: "<DB>.<SCHEMA>.MY_UDF"
           config:
             type: "function"
             warehouse: "<WH>"
             input_schema: { type: "object", properties: { ... } }
   $$;
   ```
3. In Copilot Studio, refresh the MCP connector (remove and re-add the tool)
4. The new tool appears in the tools list — enable it

**To graduate from Pattern A to Pattern C:**

1. Build a Semantic View over the tables already exposed as Knowledge Source
2. Create a Cortex Agent referencing the Semantic View
3. Create an MCP Server wrapping the Agent
4. Add Pattern C's OAuth integration (different from Pattern A's External OAuth)
5. Add MCP tool in Copilot Studio alongside existing Knowledge Source
6. Test both paths, then disable the Knowledge Source once Pattern C is validated

## Snowflake Objects

None created by this guide. All SQL is for the reader to execute in their own environment.

## Gotchas

- Pattern A/B use External OAuth (Entra issues tokens); Pattern C uses Snowflake OAuth (Snowflake issues tokens) — different security integrations
- `OAUTH_REDIRECT_URI` chicken-and-egg: create integration with placeholder, get real URL from Copilot, then ALTER
- Snowflake OAuth does NOT support `session:role-any` from Copilot — must specify single role in scope
- MCP Server hostnames must use hyphens, never underscores
- `EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = 'sub'` for service principal (Pattern A/B) vs `upn` for delegated user flow
- Copilot Studio MCP connector is stateless per call — multi-turn context is not preserved between invocations
- Power Platform DLP policies can block the Snowflake connector — check PPAC before troubleshooting auth
- The Snowflake warehouse must be running when creating the first connection (Pattern A)
- Agent tool descriptions drive Copilot's tool selection — vague descriptions cause routing failures
