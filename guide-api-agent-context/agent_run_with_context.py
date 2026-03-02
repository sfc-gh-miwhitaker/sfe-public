#!/usr/bin/env python3
"""
Working example of calling the Snowflake agent:run API with execution context.

This demonstrates how to:
1. Set role and warehouse in execution environment
2. Create a thread for conversation context
3. Send messages to an agent
4. Handle streaming responses

Requirements:
    pip install snowflake-connector-python requests

Environment Variables:
    SNOWFLAKE_ACCOUNT: Your Snowflake account identifier (e.g., 'myorg-myaccount')
    SNOWFLAKE_USER: Your Snowflake username
    SNOWFLAKE_PASSWORD: Your password (or use OAuth/key pair)

    OR use a Personal Access Token (PAT):
    SNOWFLAKE_PAT: Your Personal Access Token
"""

import os
import sys
import json
import requests
from typing import Optional

def get_auth_token(
    account: str,
    user: Optional[str] = None,
    password: Optional[str] = None,
    pat: Optional[str] = None
) -> str:
    """
    Get authentication token for Snowflake API.

    For PAT: Just use the PAT directly as Bearer token.
    For username/password: Exchange for OAuth token.
    """
    if pat:
        return pat

    if not (user and password):
        raise ValueError("Either PAT or user+password required")

    token_url = f"https://{account}.snowflakecomputing.com/oauth/token"

    response = requests.post(
        token_url,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data={
            "grant_type": "password",
            "username": user,
            "password": password,
        }
    )
    response.raise_for_status()
    return response.json()["access_token"]


def create_thread(account: str, token: str) -> str:
    """
    Create a conversation thread.

    Returns the thread_id for use in subsequent requests.
    """
    url = f"https://{account}.snowflakecomputing.com/api/v2/cortex/threads"

    response = requests.post(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json={"origin_application": "agent_run_example"}
    )
    response.raise_for_status()

    thread_data = response.json()
    return thread_data["id"]


def run_agent_with_context(
    account: str,
    token: str,
    database: str,
    schema: str,
    agent_name: str,
    thread_id: str,
    parent_message_id: int,
    user_message: str,
    role: Optional[str] = None,
    warehouse: Optional[str] = None,
    query_timeout: int = 60
) -> None:
    """
    Run an agent with specific role and warehouse context.

    Args:
        account: Snowflake account identifier
        token: Auth token (PAT or OAuth)
        database: Database containing the agent
        schema: Schema containing the agent
        agent_name: Name of the agent
        thread_id: Thread ID for conversation context
        parent_message_id: Parent message ID (0 for first message)
        user_message: The user's question/message
        role: Snowflake role to use (optional, uses caller's default if not specified)
        warehouse: Warehouse to use for execution (optional, uses caller's default if not specified)
        query_timeout: Query timeout in seconds
    """
    url = f"https://{account}.snowflakecomputing.com/api/v2/databases/{database}/schemas/{schema}/agents/{agent_name}:run"

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    if role:
        headers["X-Snowflake-Context"] = json.dumps({"currentRole": role})

    payload = {
        "thread_id": thread_id,
        "parent_message_id": parent_message_id,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": user_message
                    }
                ]
            }
        ]
    }

    print(f"\n{'='*80}")
    print(f"Calling agent: {database}.{schema}.{agent_name}")
    if role:
        print(f"Using role: {role}")
    if warehouse:
        print(f"Using warehouse: {warehouse}")
    print(f"Question: {user_message}")
    print(f"{'='*80}\n")

    with requests.post(url, headers=headers, json=payload, stream=True) as response:
        response.raise_for_status()

        print("Agent response:")
        print("-" * 80)

        for line in response.iter_lines():
            if not line:
                continue

            line = line.decode('utf-8')

            if line.startswith('event:'):
                event_type = line.split(':', 1)[1].strip()
                continue

            if line.startswith('data:'):
                data = line.split(':', 1)[1].strip()

                try:
                    event_data = json.loads(data)

                    if event_type == 'response.text.delta':
                        print(event_data.get('text', ''), end='', flush=True)

                    elif event_type == 'response.status':
                        status = event_data.get('status', '')
                        message = event_data.get('message', '')
                        print(f"\n[Status: {status}] {message}")

                    elif event_type == 'response.tool_use':
                        tool_name = event_data.get('name', '')
                        tool_type = event_data.get('type', '')
                        print(f"\n[Using tool: {tool_name} ({tool_type})]")

                    elif event_type == 'response.tool_result':
                        tool_name = event_data.get('name', '')
                        status = event_data.get('status', '')
                        print(f"\n[Tool {tool_name} completed: {status}]")

                    elif event_type == 'response':
                        print(f"\n\n[Final response received]")

                    elif event_type == 'metadata':
                        msg_id = event_data.get('message_id', '')
                        role = event_data.get('role', '')
                        if role == 'assistant':
                            print(f"\n[Message ID for follow-up: {msg_id}]")

                    elif event_type == 'error':
                        print(f"\n[ERROR] {event_data.get('message', 'Unknown error')}")
                        print(f"Code: {event_data.get('code', 'N/A')}")
                        print(f"Request ID: {event_data.get('request_id', 'N/A')}")

                except json.JSONDecodeError:
                    pass

        print("\n" + "-" * 80)


def run_agent_without_agent_object(
    account: str,
    token: str,
    thread_id: str,
    parent_message_id: int,
    user_message: str,
    semantic_view: str,
    warehouse: str,
    role: Optional[str] = None,
    query_timeout: int = 60
) -> None:
    """
    Run agent without creating an agent object (inline configuration).

    This uses the /api/v2/cortex/agent:run endpoint and allows you to
    specify the execution environment inline, including role and warehouse.

    NOTE: This method supports only a single tool per request.
    """
    url = f"https://{account}.snowflakecomputing.com/api/v2/cortex/agent:run"

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    if role:
        headers["X-Snowflake-Context"] = json.dumps({"currentRole": role})

    payload = {
        "thread_id": thread_id,
        "parent_message_id": parent_message_id,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": user_message
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
                "semantic_view": semantic_view,
                "execution_environment": {
                    "type": "warehouse",
                    "warehouse": warehouse,
                    "query_timeout": query_timeout
                }
            }
        }
    }

    print(f"\n{'='*80}")
    print(f"Calling agent (without agent object)")
    if role:
        print(f"Using role: {role}")
    print(f"Using warehouse: {warehouse}")
    print(f"Question: {user_message}")
    print(f"{'='*80}\n")

    with requests.post(url, headers=headers, json=payload, stream=True) as response:
        response.raise_for_status()

        print("Agent response:")
        print("-" * 80)

        for line in response.iter_lines():
            if not line:
                continue

            line = line.decode('utf-8')

            if line.startswith('event:'):
                event_type = line.split(':', 1)[1].strip()
                continue

            if line.startswith('data:'):
                data = line.split(':', 1)[1].strip()

                try:
                    event_data = json.loads(data)

                    if event_type == 'response.text.delta':
                        print(event_data.get('text', ''), end='', flush=True)

                    elif event_type == 'response.status':
                        status = event_data.get('status', '')
                        message = event_data.get('message', '')
                        print(f"\n[Status: {status}] {message}")

                    elif event_type == 'response':
                        print(f"\n\n[Final response received]")

                except json.JSONDecodeError:
                    pass

        print("\n" + "-" * 80)


def main():
    account = os.getenv("SNOWFLAKE_ACCOUNT")
    user = os.getenv("SNOWFLAKE_USER")
    password = os.getenv("SNOWFLAKE_PASSWORD")
    pat = os.getenv("SNOWFLAKE_PAT")

    if not account:
        print("Error: SNOWFLAKE_ACCOUNT environment variable required")
        print("Format: myorg-myaccount")
        sys.exit(1)

    if not pat and not (user and password):
        print("Error: Either SNOWFLAKE_PAT or SNOWFLAKE_USER+SNOWFLAKE_PASSWORD required")
        sys.exit(1)

    try:
        print("Authenticating...")
        token = get_auth_token(account, user, password, pat)
        print("✓ Authenticated")

        print("\nCreating thread...")
        thread_id = create_thread(account, token)
        print(f"✓ Thread created: {thread_id}")

        print("\n" + "="*80)
        print("EXAMPLE 1: Agent with execution context")
        print("="*80)

        run_agent_with_context(
            account=account,
            token=token,
            database="MYDB",
            schema="MYSCHEMA",
            agent_name="my_agent",
            thread_id=thread_id,
            parent_message_id=0,
            user_message="What were the top 5 products by revenue last month?",
            role="ANALYST_ROLE",
            warehouse="ANALYTICS_WH",
            query_timeout=120
        )

        print("\n" + "="*80)
        print("EXAMPLE 2: Agent without agent object (inline config)")
        print("="*80)

        thread_id_2 = create_thread(account, token)

        run_agent_without_agent_object(
            account=account,
            token=token,
            thread_id=thread_id_2,
            parent_message_id=0,
            user_message="What is the total sales by region?",
            semantic_view="SALES_DB.ANALYTICS.SALES_SEMANTIC_VIEW",
            warehouse="COMPUTE_WH",
            role="ANALYST_ROLE",
            query_timeout=60
        )

    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
