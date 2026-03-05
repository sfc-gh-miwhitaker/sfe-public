# MCP Integration Path

Cortex Cost Intelligence is **MCP-ready** — the monitoring views and semantic view
can be exposed as Model Context Protocol tools for use in Claude Desktop, Cursor,
CoCo, or any MCP-compatible client.

## Architecture

```
MCP Client (Claude Desktop / Cursor / CoCo)
    |
    v
Snowflake MCP Connector
    |
    v
SV_CORTEX_COST_INTELLIGENCE  (semantic view)
V_COST_INTELLIGENCE_FLAT     (direct SQL)
V_CORTEX_DAILY_SUMMARY       (direct SQL)
PROC_CHECK_USER_BUDGETS      (governance)
```

## Prerequisites

1. Snowflake MCP Connector configured and running
2. Cortex Cost Intelligence deployed (`deploy_all.sql`)
3. MCP client configured to connect to the Snowflake MCP Connector

## Example MCP Tool Definitions

### Tool: `cortex_cost_summary`

```json
{
  "name": "cortex_cost_summary",
  "description": "Get a summary of Cortex AI costs for a given time period",
  "inputSchema": {
    "type": "object",
    "properties": {
      "days": {
        "type": "integer",
        "description": "Number of days to look back (default: 30)",
        "default": 30
      }
    }
  },
  "sql": "SELECT service_type, SUM(total_credits) AS credits, SUM(total_operations) AS operations FROM SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.V_CORTEX_DAILY_SUMMARY WHERE usage_date >= DATEADD('day', -${days}, CURRENT_DATE()) GROUP BY service_type ORDER BY credits DESC"
}
```

### Tool: `cortex_cost_by_user`

```json
{
  "name": "cortex_cost_by_user",
  "description": "Get per-user Cortex AI spend for the current month",
  "inputSchema": {
    "type": "object",
    "properties": {
      "top_n": {
        "type": "integer",
        "description": "Number of top users to return",
        "default": 10
      }
    }
  },
  "sql": "SELECT user_name, SUM(credits) AS total_credits, SUM(cost_usd) AS total_cost_usd FROM SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.V_COST_INTELLIGENCE_FLAT WHERE usage_month = DATE_TRUNC('month', CURRENT_DATE()) AND user_name != 'SYSTEM' GROUP BY user_name ORDER BY total_credits DESC LIMIT ${top_n}"
}
```

### Tool: `cortex_cost_anomalies`

```json
{
  "name": "cortex_cost_anomalies",
  "description": "Get active cost anomalies (week-over-week spikes)",
  "inputSchema": { "type": "object", "properties": {} },
  "sql": "SELECT * FROM SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.V_COST_ANOMALIES_CURRENT"
}
```

## Using with Cortex Agent (Recommended)

Instead of defining individual SQL tools, point the MCP client at the
Cortex Agent which already has the semantic view as its tool:

```
Agent: SNOWFLAKE_INTELLIGENCE.AGENTS.CORTEX_COST_INTELLIGENCE
```

The agent handles natural-language question interpretation, SQL generation,
and response formatting — making it the simplest integration path.

## Status

This is documentation only. No MCP server code is included.
The architecture is MCP-ready; build the connector when
Snowflake's MCP server support matures.
