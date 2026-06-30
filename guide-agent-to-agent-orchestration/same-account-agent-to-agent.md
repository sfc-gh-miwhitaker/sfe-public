![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)

# Working Spec: Same-Account Agent → Agent

A copy-and-adapt walkthrough for the most common case — one AI agent handing part of a question to another, where **both live in the same Snowflake account**. No installed apps, no cross-app permission setup. Everything here is production-ready (GA) and pastes straight into a Snowflake SQL worksheet (the query editor in Snowflake's web interface).

> **New to Snowflake?** A quick reminder of the pieces below (full definitions in the [main guide's glossary](README.md#new-to-snowflake-read-these-words-once)):
> - **Agent** = an AI assistant that answers by calling tools. **Tool** = one capability it can call.
> - **Stored procedure** = a block of code saved in Snowflake that you run by name.
> - **`EXECUTE AS OWNER`** = that code runs with its creator's permissions, so callers don't each need their own.
> - **`DATA_AGENT_RUN`** = the built-in function that runs a named agent.
> - **Semantic view** = a business-friendly map of your tables. **Warehouse** = the compute that runs it all.

> **The code is illustrative.** The names, the semantic view, and the warehouse are placeholders — swap in your own. Snowflake's agent format is still evolving, so check the field names against the [current Run API reference](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run) before a real run.

## The shape

```
Parent agent  ──(calls a tool that is really a saved procedure)──▶  Wrapper procedure (EXECUTE AS OWNER)
                                                   │
                                                   ▼
                                     DATA_AGENT_RUN('DB.SCHEMA.CHILD_AGENT', …)
                                                   │
                                                   ▼
                                          Child agent runs its own tools
```

The parent agent never "knows" it's calling another agent. It just sees a tool that takes a `message` (text in) and returns text (the answer out). The small wrapper procedure in the middle is the only glue holding it together.

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

`EXECUTE AS OWNER` means the procedure runs with *its creator's* permissions, so the parent agent doesn't need its own access to the child. The procedure builds the request and calls `DATA_AGENT_RUN`.

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

`DATA_AGENT_RUN` returns the whole answer at once as JSON text (it never streams word-by-word). The procedure hands that text straight back to the parent agent, which reads it.

## Step 3 — Parent agent exposes the wrapper as a tool

The parent lists the wrapper procedure as one of its tools. The tool's `name` (here `MarketAgent`) and its matching entry under `tool_resources` must be spelled *exactly* the same, or the tool silently won't fire.

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

Passing `TRUE` as the third argument tells Snowflake to start a fresh conversation and return its ID (`thread_id`) so you can ask follow-up questions in the same thread. Behind the scenes: the parent agent decides to call `MarketAgent`, the wrapper procedure runs the child agent, and the child's answer flows back up to the parent.

## Gotchas

| Issue | Fix |
|---|---|
| **Name mismatch** | The tool's `name`, its `tool_resources` key, and the input field the parent fills in must all match exactly. A typo means the tool silently never runs. |
| **Single-quote escaping** | The request is JSON text placed inside SQL text, so any `'` must be doubled to `''` (the wrapper does this for you). Cleaner option: pass values as parameters instead of building the string by hand. |
| **No word-by-word streaming** | Both `DATA_AGENT_RUN` and `AGENT_RUN` return the full answer in one piece. If your app needs the answer to appear as it's typed, call Snowflake's Cortex Agents web API directly instead of these SQL functions. |
| **Don't reach for `AGENT_RUN` here** | `AGENT_RUN` is for one-off agents you define inline. For one agent calling another, use the *named*, saved child via `DATA_AGENT_RUN`. |
| **Need predictable, repeatable behavior?** | Whether the parent calls the child is decided by an AI model, so it isn't guaranteed. If you need reliable ordering or automatic retries, run `DATA_AGENT_RUN` from a scheduled **Task** or a stored procedure instead of letting one agent freely call another. |
| **Different accounts or installed apps?** | This same-account pattern needs no special permission setup. The moment the two agents live in separate installed apps, you enter [installed-app territory](README.md#3-agents-in-two-different-installed-apps-preview--available-to-all-accounts) — where Restricted Caller's Rights, `GRANT CALLER`, and the "permissions don't pass down the chain" rule all apply. |

## References

- [`DATA_AGENT_RUN` (SNOWFLAKE.CORTEX)](https://docs.snowflake.com/en/sql-reference/functions/data_agent_run-snowflake-cortex)
- [Cortex Agents Run API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run)
- [Create and manage agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage)
- [Inter-app agents (cross-app variant of this pattern)](https://docs.snowflake.com/en/developer-guide/native-apps/inter-app-agents)
