# Snowflake Agent API - curl/Bash Examples

This demonstrates how to call the Snowflake agent:run API with execution context using curl and bash.

## Prerequisites

- `curl` command-line tool
- `jq` for JSON parsing
- Snowflake Personal Access Token (PAT)

## Setup

Set your credentials:

```bash
export SNOWFLAKE_ACCOUNT="myorg-myaccount"
export SNOWFLAKE_PAT="your-personal-access-token"
```

## Example 1: Create a Thread

```bash
THREAD_RESPONSE=$(curl -s -X POST \
  "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/threads" \
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}" \
  -H "Content-Type: application/json" \
  -d '{"origin_application": "agent_run_example"}')

THREAD_ID=$(echo "$THREAD_RESPONSE" | jq -r '.id')
echo "Thread ID: $THREAD_ID"
```

## Example 2: Call Agent with Execution Context

Call an existing agent with specific role and warehouse:

```bash
curl -X POST \
  "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/databases/MYDB/schemas/MYSCHEMA/agents/my_agent:run" \
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}" \
  -H "Content-Type: application/json" \
  -H "X-Snowflake-Role: ANALYST_ROLE" \
  -d '{
    "thread_id": "'"$THREAD_ID"'",
    "parent_message_id": 0,
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text": "What were the top 5 products by revenue last month?"
          }
        ]
      }
    ]
  }' \
  --no-buffer
```

## Example 3: Call Agent Without Agent Object (Inline Config)

Call agent API directly with inline configuration:

```bash
THREAD_ID_2=$(curl -s -X POST \
  "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/threads" \
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}" \
  -H "Content-Type: application/json" \
  -d '{"origin_application": "agent_run_example"}' | jq -r '.id')

curl -X POST \
  "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/agent:run" \
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}" \
  -H "Content-Type: application/json" \
  -H "X-Snowflake-Role: ANALYST_ROLE" \
  -d '{
    "thread_id": "'"$THREAD_ID_2"'",
    "parent_message_id": 0,
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text": "What is the total sales by region?"
          }
        ]
      }
    ],
    "models": {
      "orchestration": "claude-4-sonnet"
    },
    "instructions": {
      "response": "Be concise and data-driven.",
      "orchestration": "Use the analyst tool to answer data questions."
    },
    "tools": [
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "data_analyst",
          "description": "Query structured data"
        }
      }
    ],
    "tool_resources": {
      "data_analyst": {
        "semantic_view": "SALES_DB.ANALYTICS.SALES_SEMANTIC_VIEW",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "COMPUTE_WH",
          "query_timeout": 60
        }
      }
    }
  }' \
  --no-buffer
```

## Complete Script

```bash
#!/bin/bash

export SNOWFLAKE_ACCOUNT="myorg-myaccount"
export SNOWFLAKE_PAT="your-personal-access-token"

THREAD_RESPONSE=$(curl -s -X POST \
  "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/threads" \
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}" \
  -H "Content-Type: application/json" \
  -d '{"origin_application": "agent_run_example"}')

THREAD_ID=$(echo "$THREAD_RESPONSE" | jq -r '.id')
echo "Thread ID: $THREAD_ID"

curl -X POST \
  "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/databases/MYDB/schemas/MYSCHEMA/agents/my_agent:run" \
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}" \
  -H "Content-Type: application/json" \
  -H "X-Snowflake-Role: ANALYST_ROLE" \
  -d '{
    "thread_id": "'"$THREAD_ID"'",
    "parent_message_id": 0,
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text": "What were the top 5 products by revenue last month?"
          }
        ]
      }
    ]
  }' \
  --no-buffer
```

## Key Points

- **Role context**: Use `X-Snowflake-Role` header (e.g., `X-Snowflake-Role: ANALYST_ROLE`)
- **Warehouse context**: Use `X-Snowflake-Warehouse` header or set in `tool_resources` → `execution_environment` → `warehouse`
- **Streaming**: Use `--no-buffer` flag to see streaming responses in real-time
- **Thread management**: Create a thread once, reuse for multi-turn conversations
- **Parent message ID**: Use `0` for first message, then use returned message IDs for follow-ups

## API Endpoints

- Create thread: `POST /api/v2/cortex/threads`
- Run agent (with object): `POST /api/v2/databases/{db}/schemas/{schema}/agents/{name}:run`
- Run agent (inline): `POST /api/v2/cortex/agent:run`
