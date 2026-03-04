---
name: demo-cortex-teams-agent
description: "Cortex Agent deployed to Microsoft Teams and M365 Copilot. Triggers: teams agent, teams bot, M365 copilot agent, entra ID agent, joke assistant, AI_COMPLETE guardrails, security integration external oauth."
---

# Cortex Agents for Microsoft Teams & M365 Copilot

## Purpose

Deploy a Snowflake Cortex Agent to Microsoft Teams and Microsoft 365 Copilot. The demo uses a joke generator with Cortex Guard content safety; the same architecture powers production analytics agents with Cortex Analyst and Cortex Search tools.

## When to Use

- Creating or modifying the Teams/M365 agent integration
- Adding new tools to the agent specification
- Setting up Entra ID OAuth or security integration
- Extending the joke demo toward production analytics patterns

## Architecture

```
Teams / M365 Copilot
       │
       ▼
Entra ID (OAuth 2.0)     ← Two app consents required
       │
       ▼
Snowflake Security Integration (EXTERNAL_OAUTH)
       │
       ▼
Cortex Agent (JOKE_ASSISTANT)
       │
       ▼
Custom Tool → GENERATE_SAFE_JOKE UDF
       │
       ▼
AI_COMPLETE + Cortex Guard
```

## Key Files

| File | Purpose |
|------|---------|
| `sql/01_setup/01_create_demo_objects.sql` | Schema, warehouse, grants |
| `sql/01_setup/02_create_joke_function.sql` | GENERATE_SAFE_JOKE UDF via AI_COMPLETE |
| `sql/01_setup/03_create_agent.sql` | CREATE AGENT DDL with YAML spec + production template |
| `sql/01_setup/04_create_security_integration.sql` | External OAuth security integration |
| `sql/01_setup/05_grant_permissions.sql` | RBAC grants for agent access |
| `docs/02-ENTRA-ID-SETUP.md` | Entra ID app registration walkthrough |
| `docs/03-INSTALL-TEAMS-APP.md` | Teams app installation steps |
| `docs/04-CUSTOMIZATION.md` | Model swap, production patterns, monitoring |

## Agent Specification Pattern

```yaml
models:
  orchestration: auto          # ALWAYS auto, never pin a model
orchestration:
  budget:
    seconds: 30                # Always set budget limits
    tokens: 8000
instructions:
  system: ...                  # Agent persona
  response: ...                # Output formatting
  orchestration: ...           # Tool-calling strategy
  sample_questions: [...]      # Suggested prompts
tools:
  - tool_spec:
      type: "custom_tool"     # custom_tool in YAML, generic in REST API
      name: "joke_generator"
tool_resources:
  joke_generator:
    type: "function"
    identifier: "SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.GENERATE_SAFE_JOKE"
    execution_environment:
      type: "warehouse"
      warehouse: "SFE_TEAMS_AGENT_UNI_WH"
```

## Extension Playbook: Adding a New Tool

1. Create the UDF or identify the Cortex Search/Analyst resource
2. Add a `tool_spec` entry under `tools:` in the agent YAML
3. Add a matching `tool_resources:` entry with the resource identifier
4. Update `instructions.orchestration` to guide when the new tool is used
5. Recreate the agent: `CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$...$$;`
6. Verify: `DESCRIBE AGENT <name>;` then test in Teams

**Tool type mapping:**

| Tool | YAML `type` | REST API `type` |
|------|------------|----------------|
| SQL UDF | `custom_tool` | `generic` |
| Cortex Analyst | `cortex_analyst_text_to_sql` | same |
| Cortex Search | `cortex_search` | same |

## Extension Playbook: Swapping to a Production Agent

See `docs/04-CUSTOMIZATION.md` and the commented production template in `sql/01_setup/03_create_agent.sql`. Key steps:

1. Replace `custom_tool` with `cortex_analyst_text_to_sql` or `cortex_search`
2. Update `tool_resources` to reference a semantic view or search service
3. Increase budget (`seconds: 60`, `tokens: 16000`) for analytics workloads
4. Add RBAC grants for the production role
5. Security integration and Teams app remain unchanged

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI` |
| Warehouse | `SFE_TEAMS_AGENT_UNI_WH` |
| Agent | `JOKE_ASSISTANT` |
| Function | `GENERATE_SAFE_JOKE(VARCHAR)` |
| Security Integration | External OAuth for Entra ID |

## Gotchas

- **Two Entra ID consents**: Both the OAuth Resource app and OAuth Client app need admin consent
- **SHOW AGENTS** not SHOW CORTEX AGENTS
- **AI_COMPLETE guardrails**: Boolean `true`, not the old object-reference syntax
- **Tool type mismatch**: `custom_tool` in CREATE AGENT DDL vs `generic` in REST API payloads
- Agent changes reflect across all interfaces (Snowsight, Teams, M365 Copilot) immediately
