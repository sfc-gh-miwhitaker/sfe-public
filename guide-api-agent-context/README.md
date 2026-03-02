# Agent:Run API with Context - Examples

This directory contains working examples of calling the Snowflake `agent:run` API with execution context (role and warehouse).

## Files

### `agent_run_with_context.py`

Complete Python example demonstrating:

1. **Setting execution context (role and warehouse)**
   - Using `X-Snowflake-Context` header for role
   - Specifying warehouse in `execution_environment` for tool resources

2. **Two approaches:**
   - **With agent object**: Call existing agent with context override
   - **Without agent object**: Inline agent configuration with context

3. **Thread management** for multi-turn conversations

4. **Streaming response handling** for real-time feedback

## Key Concepts

### Setting Role

Use the `X-Snowflake-Context` header:

```python
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
    "X-Snowflake-Context": json.dumps({"currentRole": "ANALYST_ROLE"})
}
```

### Setting Warehouse

Specify in the tool's `execution_environment`:

```python
"tool_resources": {
    "my_tool": {
        "semantic_view": "DB.SCHEMA.VIEW",
        "execution_environment": {
            "type": "warehouse",
            "warehouse": "ANALYTICS_WH",  # Warehouse name (case-sensitive, UPPERCASE if unquoted)
            "query_timeout": 60            # Optional timeout in seconds
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

Common errors:

1. **Invalid role**: Check role exists and user has access
2. **Invalid warehouse**: Check warehouse exists and is accessible
3. **Permission denied**: Verify role has USAGE on agent and underlying resources
4. **Timeout**: Increase `query_timeout` in execution environment

## References

- [Cortex Agents Run API Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run)
- [Cortex Agents REST API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-rest-api)
- [Execution Environment Schema](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run#label-snowflake-agent-run-executionenvironment)
