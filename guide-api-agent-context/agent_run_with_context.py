#!/usr/bin/env python3
"""
Working example of calling the Snowflake agent:run API with execution context.

This demonstrates how to:
1. Set role and warehouse via HTTP headers
2. Create a thread for conversation context
3. Send messages to an agent
4. Handle streaming responses

Requirements:
    pip install requests

    For key-pair JWT auth only (option 3):
    pip install cryptography

Environment Variables:
    SNOWFLAKE_ACCOUNT: Your Snowflake account identifier (e.g., 'myorg-myaccount')

    Option 1 - Personal Access Token (recommended for quick testing):
    SNOWFLAKE_PAT: Your Personal Access Token

    Option 2 - OAuth (client credentials):
    SNOWFLAKE_OAUTH_CLIENT_ID: OAuth client ID
    SNOWFLAKE_OAUTH_CLIENT_SECRET: OAuth client secret

    Option 3 - Key-Pair JWT (service accounts, CI/CD, no-password):
    SNOWFLAKE_USER: Snowflake username with RSA public key assigned
    SNOWFLAKE_PRIVATE_KEY_PATH: Path to PEM-encoded RSA private key file
    See: https://docs.snowflake.com/en/user-guide/key-pair-auth
"""

import os
import sys
import json
import time
from typing import Optional, Tuple, Dict
from urllib.parse import urlencode

import requests


def get_oauth_token(
    account: str,
    client_id: str,
    client_secret: str,
    scope: str = "session:role:PUBLIC"
) -> str:
    """
    Get OAuth access token using client credentials flow.

    Args:
        account: Snowflake account identifier (e.g., 'myorg-myaccount')
        client_id: OAuth client ID from security integration
        client_secret: OAuth client secret
        scope: OAuth scope (default: session:role:PUBLIC)

    Returns:
        Access token string

    To create an OAuth integration in Snowflake:
        CREATE SECURITY INTEGRATION my_oauth_int
            TYPE = OAUTH
            OAUTH_CLIENT = CUSTOM
            OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
            OAUTH_REDIRECT_URI = 'https://localhost'
            OAUTH_ISSUE_REFRESH_TOKENS = TRUE
            OAUTH_REFRESH_TOKEN_VALIDITY = 86400
            ENABLED = TRUE;

        -- Get client ID and secret:
        SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('MY_OAUTH_INT');
    """
    token_url = f"https://{account}.snowflakecomputing.com/oauth/token"

    response = requests.post(
        token_url,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data=urlencode({
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": scope,
        }),
        timeout=30
    )
    response.raise_for_status()
    return response.json()["access_token"]


def generate_keypair_jwt(
    account: str,
    user: str,
    private_key_path: str,
    expires_in_seconds: int = 3600,
) -> str:
    """
    Generate a Snowflake KEYPAIR_JWT token from an RSA private key.

    Requires: pip install cryptography

    Snowflake setup (one-time, as ACCOUNTADMIN):
        ALTER USER <user> SET RSA_PUBLIC_KEY='<public key without header/footer>';

    See: https://docs.snowflake.com/en/user-guide/key-pair-auth
    """
    import hashlib
    import math
    import base64
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    def _b64url(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")

    pem_bytes = open(private_key_path, "rb").read()
    private_key = serialization.load_pem_private_key(pem_bytes, password=None)

    public_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    fingerprint = base64.b64encode(hashlib.sha256(public_der).digest()).decode("ascii")

    normalized_account = (
        account.strip()
        .replace(".snowflakecomputing.com", "")
        .replace(".", "-")
        .upper()
    )
    username = user.strip().upper()
    qualified = f"{normalized_account}.{username}"

    now = math.floor(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    payload = {
        "iss": f"{qualified}.SHA256:{fingerprint}",
        "sub": qualified,
        "iat": now,
        "exp": now + expires_in_seconds,
    }

    signing_input = f"{_b64url(json.dumps(header).encode())}.{_b64url(json.dumps(payload).encode())}"
    signature = private_key.sign(
        signing_input.encode(), padding.PKCS1v15(), hashes.SHA256()
    )
    return f"{signing_input}.{_b64url(signature)}"


def get_auth_token(
    account: str,
    pat: Optional[str] = None,
    oauth_client_id: Optional[str] = None,
    oauth_client_secret: Optional[str] = None,
    user: Optional[str] = None,
    private_key_path: Optional[str] = None,
) -> Tuple[str, Dict[str, str]]:
    """
    Get authentication token and any extra headers for the Snowflake API.

    Returns (token, extra_headers). For PAT and OAuth the extra headers dict
    is empty.  For key-pair JWT it contains X-Snowflake-Authorization-Token-Type.

    Priority: PAT > Key-Pair JWT > OAuth client credentials
    """
    if pat:
        return pat, {}

    if user and private_key_path:
        token = generate_keypair_jwt(account, user, private_key_path)
        return token, {"X-Snowflake-Authorization-Token-Type": "KEYPAIR_JWT"}

    if oauth_client_id and oauth_client_secret:
        return get_oauth_token(account, oauth_client_id, oauth_client_secret), {}

    raise ValueError(
        "One of the following is required:\n"
        "  - SNOWFLAKE_PAT\n"
        "  - SNOWFLAKE_USER + SNOWFLAKE_PRIVATE_KEY_PATH\n"
        "  - SNOWFLAKE_OAUTH_CLIENT_ID + SNOWFLAKE_OAUTH_CLIENT_SECRET"
    )


def create_thread(
    account: str,
    token: str,
    extra_headers: Optional[Dict[str, str]] = None,
) -> str:
    """
    Create a conversation thread.

    Returns the thread_id for use in subsequent requests.
    """
    url = f"https://{account}.snowflakecomputing.com/api/v2/cortex/threads"

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        **(extra_headers or {}),
    }

    response = requests.post(
        url,
        headers=headers,
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
    extra_headers: Optional[Dict[str, str]] = None,
    query_timeout: int = 60
) -> None:
    """
    Run an agent with specific role and warehouse context.

    Args:
        account: Snowflake account identifier
        token: Auth token (PAT, OAuth, or Key-Pair JWT)
        database: Database containing the agent
        schema: Schema containing the agent
        agent_name: Name of the agent
        thread_id: Thread ID for conversation context
        parent_message_id: Parent message ID (0 for first message)
        user_message: The user's question/message
        role: Snowflake role to use (optional, uses caller's default if not specified)
        warehouse: Warehouse to use for execution (optional, uses caller's default if not specified)
        extra_headers: Additional headers (e.g. KEYPAIR_JWT token-type header)
        query_timeout: Query timeout in seconds
    """
    url = f"https://{account}.snowflakecomputing.com/api/v2/databases/{database}/schemas/{schema}/agents/{agent_name}:run"

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        **(extra_headers or {}),
    }

    # Use official Snowflake headers for role and warehouse context
    # See: https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/setting-context
    if role:
        headers["X-Snowflake-Role"] = role
    if warehouse:
        headers["X-Snowflake-Warehouse"] = warehouse

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
    extra_headers: Optional[Dict[str, str]] = None,
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
        **(extra_headers or {}),
    }

    # Use official Snowflake headers for role and warehouse context
    # See: https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/setting-context
    if role:
        headers["X-Snowflake-Role"] = role

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
    pat = os.getenv("SNOWFLAKE_PAT")
    oauth_client_id = os.getenv("SNOWFLAKE_OAUTH_CLIENT_ID")
    oauth_client_secret = os.getenv("SNOWFLAKE_OAUTH_CLIENT_SECRET")
    user = os.getenv("SNOWFLAKE_USER")
    private_key_path = os.getenv("SNOWFLAKE_PRIVATE_KEY_PATH")

    if not account:
        print("Error: SNOWFLAKE_ACCOUNT environment variable required")
        print("Format: myorg-myaccount")
        sys.exit(1)

    has_pat = bool(pat)
    has_oauth = bool(oauth_client_id and oauth_client_secret)
    has_keypair = bool(user and private_key_path)

    if not (has_pat or has_oauth or has_keypair):
        print("Error: One of the following is required:")
        print("  - SNOWFLAKE_PAT")
        print("  - SNOWFLAKE_USER + SNOWFLAKE_PRIVATE_KEY_PATH")
        print("  - SNOWFLAKE_OAUTH_CLIENT_ID + SNOWFLAKE_OAUTH_CLIENT_SECRET")
        sys.exit(1)

    try:
        print("Authenticating...")
        token, extra_headers = get_auth_token(
            account=account,
            pat=pat,
            oauth_client_id=oauth_client_id,
            oauth_client_secret=oauth_client_secret,
            user=user,
            private_key_path=private_key_path,
        )
        auth_method = "Key-Pair JWT" if extra_headers else ("PAT" if pat else "OAuth")
        print(f"OK  Authenticated via {auth_method}")

        print("\nCreating thread...")
        thread_id = create_thread(account, token, extra_headers)
        print(f"OK  Thread created: {thread_id}")

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
            extra_headers=extra_headers,
            query_timeout=120
        )

        print("\n" + "="*80)
        print("EXAMPLE 2: Agent without agent object (inline config)")
        print("="*80)

        thread_id_2 = create_thread(account, token, extra_headers)

        run_agent_without_agent_object(
            account=account,
            token=token,
            thread_id=thread_id_2,
            parent_message_id=0,
            user_message="What is the total sales by region?",
            semantic_view="SALES_DB.ANALYTICS.SALES_SEMANTIC_VIEW",
            warehouse="COMPUTE_WH",
            role="ANALYST_ROLE",
            extra_headers=extra_headers,
            query_timeout=60
        )

    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
