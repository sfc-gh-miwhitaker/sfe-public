![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)

# Working Spec: Same-Account Agent → Agent

A copy-and-adapt walkthrough for the most common case — one Cortex Agent delegating to another **in the same account**. No Native App, no inter-app handshake, no RCR. These are GA primitives you can drop into a worksheet for a customer demo.

> **Snippets are illustrative.** Object names, the semantic view, and the warehouse are placeholders. Substitute your own and confirm the agent-spec fields against the [current Run API schema](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run) before a customer-facing run — the agent spec is evolving.

## The shape

```
Parent agent  ──(generic/procedure tool)──▶  Wrapper proc (EXECUTE AS OWNER)
                                                   │
                                                   ▼
                                     DATA_AGENT_RUN('DB.SCHEMA.CHILD_AGENT', …)
                                                   │
                                                   ▼
                                          Child agent runs its own tools
```

The parent never "knows" it's calling an agent. It sees a tool that takes a `message` string and returns text. The wrapper procedure is the only glue.

## Step 1 — Child agent

The specialist. Here it answers questions over a semantic view via Cortex Analyst. (Any agent works — this is just the thing being delegated to.)

```sql
CREATE OR REPLACE AGENT my_db.my_schema.market_agent
  FROM SPECIFICATION $$
  models:
    orchestration: auto
  instructions:
    system: "You answer questions about historical market data."
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "MarketData"
        description: "Query historical market data"
  tool_resources:
    MarketData:
      semantic_view: "my_db.my_schema.market_sv"
      execution_environment:
        type: warehouse
        warehouse: "DEMO_WH"
  $$;
```

> Use `orchestration: auto`, not a pinned model name — a specific model may not exist in every region.

## Step 2 — Wrapper procedure (the glue)

`EXECUTE AS OWNER` so the parent agent doesn't need direct grants on the child. It builds the Run API request body and calls `DATA_AGENT_RUN`.

```sql
CREATE OR REPLACE PROCEDURE my_db.my_schema.run_market_agent(message STRING)
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python')
  HANDLER = 'run'
  EXECUTE AS OWNER
AS
$$
import json

def run(session, message):
    body = json.dumps({
        "messages": [
            {"role": "user", "content": [{"type": "text", "text": message}]}
        ]
    })
    escaped = body.replace("'", "''")
    rows = session.sql(
        f"SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN("
        f"  'MY_DB.MY_SCHEMA.MARKET_AGENT',"
        f"  '{escaped}'"
        f")"
    ).collect()
    return str(rows[0][0]) if rows else ''
$$;
```

`DATA_AGENT_RUN` returns **non-streaming JSON** (the `stream` field is ignored). The proc returns that JSON string straight to the parent; the orchestration model reads it.

## Step 3 — Parent agent exposes the wrapper as a tool

The child agent appears as a `generic` tool spec with a matching `procedure` resource. The `tool_spec.name` and the `tool_resources` key must match exactly.

```sql
CREATE OR REPLACE AGENT my_db.my_schema.portfolio_agent
  FROM SPECIFICATION $$
  models:
    orchestration: auto
  instructions:
    system: "You help with portfolio questions. For historical market
             data, call the MarketAgent tool."
  tools:
    - tool_spec:
        type: "generic"
        name: "MarketAgent"
        description: "Delegate historical market-data questions to the
                      market specialist agent."
        input_schema:
          type: object
          properties:
            message:
              type: string
              description: "The question to send to the market agent."
          required: ["message"]
  tool_resources:
    MarketAgent:
      identifier: "my_db.my_schema.run_market_agent"
      type: procedure
      execution_environment:
        type: warehouse
        warehouse: "DEMO_WH"
  $$;
```

## Step 4 — Run the parent

```sql
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'MY_DB.MY_SCHEMA.PORTFOLIO_AGENT',
    $${
      "messages": [
        {"role": "user",
         "content": [{"type": "text",
                      "text": "How did tech stocks move last quarter?"}]}
      ]
    }$$,
    TRUE
  )
) AS resp;
```

`create_thread_if_not_present = TRUE` (the 3rd arg) auto-creates a thread and returns its `thread_id` for follow-ups. The parent's orchestration model decides to call `MarketAgent`, the wrapper runs the child, and the child's answer flows back up.

## Gotchas

| Issue | Fix |
|---|---|
| **Name mismatch** | `tool_spec.name`, the `tool_resources` key, and the `input_schema` property the parent passes must all line up. A typo means the tool silently never fires. |
| **Single-quote escaping** | The request body is a JSON string inside a SQL string. Escape `'` → `''` (the wrapper does this). Cleaner alternative: parameterize and avoid string-building entirely. |
| **Non-streaming only** | Both `DATA_AGENT_RUN` and `AGENT_RUN` ignore `stream` and return one JSON blob. For a token-by-token UX, call the **streaming REST API** instead of the SQL wrapper. |
| **Don't reach for `AGENT_RUN` here** | `AGENT_RUN` (no agent object) is for ad-hoc inline configs. For agent→agent you want the **named** child via `DATA_AGENT_RUN`. |
| **Need deterministic chaining?** | The parent's decision to call the child is LLM-driven. If you need guaranteed ordering/retries, drive `DATA_AGENT_RUN` from a **Task or stored procedure**, not from agent delegation. |
| **Cross-account / cross-app?** | This same-account pattern has no RCR. The moment the agents live in different Native Apps, you're in [inter-app territory](README.md#3-inter-app-agents-preview--open-all-accounts): RCR, `GRANT CALLER`, and caller-grants-don't-chain apply. |

## References

- [`DATA_AGENT_RUN` (SNOWFLAKE.CORTEX)](https://docs.snowflake.com/en/sql-reference/functions/data_agent_run-snowflake-cortex)
- [Cortex Agents Run API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run)
- [Create and manage agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage)
- [Inter-app agents (cross-app variant of this pattern)](https://docs.snowflake.com/en/developer-guide/native-apps/inter-app-agents)
