# Agent:Run API with Context - Examples

> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

## Quick Start

**Get just this guide:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) guide-api-agent-context
cd sfe-public/guide-api-agent-context
```

Working examples of calling the Snowflake `agent:run` API with execution context (role and warehouse).

## Quick Test (curl)

Verify your setup before integrating into an application.

### Prerequisites

```bash
export SNOWFLAKE_ACCOUNT="myorg-myaccount"
export SNOWFLAKE_PAT="your-personal-access-token"
```

### 1. Create a Thread

```bash
THREAD_ID=$(curl -s -X POST \
  "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/threads" \
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}" \
  -H "Content-Type: application/json" \
  -d '{"origin_application": "quick_test"}' | jq -r '.id')

echo "Thread ID: $THREAD_ID"
```

### 2. Call Agent with Role Context

```bash
curl -X POST \
  "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/databases/MYDB/schemas/MYSCHEMA/agents/my_agent:run" \
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}" \
  -H "Content-Type: application/json" \
  -H "X-Snowflake-Role: ANALYST_ROLE" \
  -H "X-Snowflake-Warehouse: COMPUTE_WH" \
  -d '{
    "thread_id": "'"$THREAD_ID"'",
    "parent_message_id": 0,
    "messages": [{
      "role": "user",
      "content": [{"type": "text", "text": "What were the top 5 products by revenue last month?"}]
    }]
  }' --no-buffer
```

## Files

| File | Description |
|------|-------------|
| `agent_run_with_context.py` | Complete Python example with PAT and OAuth authentication |
| `agent_run_react.md` | React integration guide with backend proxy pattern |

## Key Concepts

### Setting Role and Warehouse

Use dedicated HTTP headers ([official documentation](https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/setting-context)):

```python
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
    "X-Snowflake-Role": "ANALYST_ROLE",      # Role for authorization
    "X-Snowflake-Warehouse": "COMPUTE_WH",   # Warehouse for execution
}
```

For tool-specific warehouse configuration, use `execution_environment`:

```python
"tool_resources": {
    "my_tool": {
        "semantic_view": "DB.SCHEMA.VIEW",
        "execution_environment": {
            "type": "warehouse",
            "warehouse": "ANALYTICS_WH",  # Warehouse name (UPPERCASE for unquoted identifiers)
            "query_timeout": 60           # Optional timeout in seconds
        }
    }
}
```

### Important Notes

1. **Warehouse naming**: Use UPPERCASE for unquoted identifiers (e.g., `"MY_WH"`), case-sensitive for quoted identifiers
2. **Role context**: Applies to the entire request, not per-tool
3. **Default behavior**: If not specified, uses caller's default role and warehouse
4. **Agent object approach**: Cannot override `models`, `instructions`, or `orchestration` via the run API
5. **Inline approach**: Full control but limited to single tool per request

## Usage

### Setup

```bash
pip install snowflake-connector-python requests
```

### Environment Variables

```bash
# Account identifier
export SNOWFLAKE_ACCOUNT="myorg-myaccount"

# Option 1: Personal Access Token (recommended)
export SNOWFLAKE_PAT="your_pat_token"

# Option 2: Username and password
export SNOWFLAKE_USER="your_username"
export SNOWFLAKE_PASSWORD="your_password" # pragma: allowlist secret
```

### Run Example

```bash
python agent_run_with_context.py
```

### Customize

Edit the `main()` function to use your:
- Database and schema names
- Agent name
- Role name
- Warehouse name
- Semantic view name

## Common Use Cases

### 1. Multi-tenant applications

Different users with different roles accessing the same agent:

```python
run_agent_with_context(
    agent_name="sales_agent",
    role="TENANT_A_ROLE",  # Changes per user
    warehouse="COMPUTE_WH",
    user_message="Show my sales data"
)
```

### 2. Workload isolation

Route heavy queries to larger warehouses:

```python
if is_heavy_query(user_message):
    warehouse = "XLARGE_WH"
else:
    warehouse = "SMALL_WH"

run_agent_with_context(
    agent_name="analytics_agent",
    warehouse=warehouse,
    user_message=user_message
)
```

### 3. Dynamic role assignment

```python
user_role = get_user_role_from_session(user_id)

run_agent_with_context(
    agent_name="data_agent",
    role=user_role,  # Different role per user
    warehouse="COMPUTE_WH",
    user_message="What data can I access?"
)
```

## Response Streaming

The example handles these event types:

- `response.text.delta` - Text tokens as they're generated
- `response.status` - Agent status updates
- `response.tool_use` - When agent calls a tool
- `response.tool_result` - Tool execution results
- `response` - Final aggregated response
- `metadata` - Message IDs for follow-up questions
- `error` - Error information

## Error Handling

### HTTP Status Codes

| Status | Meaning | Resolution |
|--------|---------|------------|
| **401 Unauthorized** | Invalid or expired token | Verify PAT is valid and not expired. For OAuth, refresh the access token. Check `SNOWFLAKE_PAT` env var is set correctly. |
| **403 Forbidden** | Role lacks required privileges | Verify the role has `USAGE` on the agent, database, schema, warehouse, and underlying semantic views/tables. Check PAT's `ROLE_RESTRICTION` if using scoped tokens. |
| **404 Not Found** | Agent, database, or schema doesn't exist | Verify the agent path: `databases/{DB}/schemas/{SCHEMA}/agents/{NAME}`. Check spelling and case sensitivity. |
| **429 Too Many Requests** | Rate limit exceeded | Implement exponential backoff. Wait and retry. Consider batching requests or increasing delays between calls. |
| **500 Internal Server Error** | Server-side error | Retry with exponential backoff. If persistent, check Snowflake status page. |

### Common Application Errors

| Error | Resolution |
|-------|------------|
| Invalid role | Check role exists (`SHOW ROLES`) and is granted to user (`SHOW GRANTS TO USER <user>`) |
| Invalid warehouse | Check warehouse exists and role has `USAGE` privilege |
| Permission denied | Verify role has `USAGE` on agent and underlying resources (semantic views, tables) |
| Query timeout | Increase `query_timeout` in `execution_environment` (default: 60s, max: 3600s) |
| Thread not found | Thread IDs expire. Create a new thread if the old one is no longer valid. |

### Retry Example

```python
import time
from requests.exceptions import HTTPError

def call_with_retry(func, max_retries=3, base_delay=1.0):
    for attempt in range(max_retries):
        try:
            return func()
        except HTTPError as e:
            if e.response.status_code == 429:
                delay = base_delay * (2 ** attempt)
                time.sleep(delay)
            elif e.response.status_code >= 500:
                time.sleep(base_delay)
            else:
                raise
    raise Exception("Max retries exceeded")
```

## References

- [Cortex Agents Run API Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run)
- [Cortex Agents REST API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-rest-api)
- [Execution Environment Schema](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run#label-snowflake-agent-run-executionenvironment)
