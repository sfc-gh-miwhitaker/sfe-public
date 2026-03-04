#!/usr/bin/env python3
"""
Key-Pair JWT authentication for the Snowflake agent:run API.

Generates RS256-signed JWTs from an RSA private key, suitable for service
accounts, CI/CD pipelines, or any environment where password/PAT auth is
not available.

Requirements:
    pip install cryptography requests

Environment Variables:
    SNOWFLAKE_ACCOUNT:          Account identifier (e.g., 'myorg-myaccount')
    SNOWFLAKE_USER:             Snowflake username with RSA public key assigned
    SNOWFLAKE_PRIVATE_KEY_PATH: Path to PEM-encoded RSA private key file

Snowflake setup (one-time):
    -- 1. Generate key pair
    openssl genrsa -out rsa_key.pem 2048
    openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub

    -- 2. Assign public key to user (run as ACCOUNTADMIN)
    ALTER USER my_user SET RSA_PUBLIC_KEY='<contents of rsa_key.pub without header/footer>';

See also:
    https://docs.snowflake.com/en/user-guide/key-pair-auth
    https://docs.snowflake.com/en/developer-guide/sql-api/authenticating
"""

import hashlib
import json
import math
import os
import sys
import time
from typing import Optional, Tuple

import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding


# ---------------------------------------------------------------------------
# JWT generation
# ---------------------------------------------------------------------------

def _base64url(data: bytes) -> str:
    import base64
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _normalize_account(account: str) -> str:
    """ACCOUNT-USER format required by Snowflake JWT: uppercase, dots→hyphens."""
    return (
        account.strip()
        .replace(".snowflakecomputing.com", "")
        .replace(".", "-")
        .upper()
    )


def _build_fingerprint(private_key_pem: bytes) -> str:
    """SHA256 fingerprint of the SPKI-encoded public key (base64)."""
    private_key = serialization.load_pem_private_key(private_key_pem, password=None)
    public_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    import base64
    return base64.b64encode(hashlib.sha256(public_der).digest()).decode("ascii")


def generate_keypair_jwt(
    account: str,
    user: str,
    private_key_pem: bytes,
    expires_in_seconds: int = 3600,
) -> Tuple[str, int]:
    """
    Build and sign a Snowflake KEYPAIR_JWT token.

    Returns (token_string, expiry_unix_timestamp).
    """
    now = math.floor(time.time())
    exp = now + expires_in_seconds

    normalized_account = _normalize_account(account)
    username = user.strip().upper()
    qualified = f"{normalized_account}.{username}"
    fingerprint = _build_fingerprint(private_key_pem)

    header = {"alg": "RS256", "typ": "JWT"}
    payload = {
        "iss": f"{qualified}.SHA256:{fingerprint}",
        "sub": qualified,
        "iat": now,
        "exp": exp,
    }

    signing_input = f"{_base64url(json.dumps(header).encode())}.{_base64url(json.dumps(payload).encode())}"

    private_key = serialization.load_pem_private_key(private_key_pem, password=None)
    signature = private_key.sign(
        signing_input.encode(),
        padding.PKCS1v15(),
        hashes.SHA256(),
    )

    token = f"{signing_input}.{_base64url(signature)}"
    return token, exp


# ---------------------------------------------------------------------------
# Token cache -- reuse until 5 minutes before expiry
# ---------------------------------------------------------------------------

_cached_token: Optional[str] = None
_cached_exp: int = 0


def get_jwt(account: str, user: str, private_key_pem: bytes) -> str:
    """Return a cached JWT, refreshing when within 5 minutes of expiry."""
    global _cached_token, _cached_exp
    now = math.floor(time.time())
    if _cached_token and (_cached_exp - 300) > now:
        return _cached_token
    _cached_token, _cached_exp = generate_keypair_jwt(account, user, private_key_pem)
    return _cached_token


# ---------------------------------------------------------------------------
# Snowflake helpers
# ---------------------------------------------------------------------------

def _build_headers(jwt: str) -> dict:
    return {
        "Authorization": f"Bearer {jwt}",
        "X-Snowflake-Authorization-Token-Type": "KEYPAIR_JWT",
        "Content-Type": "application/json",
    }


def create_thread(account: str, jwt: str) -> str:
    url = f"https://{account.strip()}.snowflakecomputing.com/api/v2/cortex/threads"
    resp = requests.post(url, headers=_build_headers(jwt), json={"origin_application": "keypair_jwt_example"})
    resp.raise_for_status()
    return resp.json()["id"]


def run_agent(
    account: str,
    jwt: str,
    database: str,
    schema: str,
    agent_name: str,
    thread_id: str,
    message: str,
    role: Optional[str] = None,
    warehouse: Optional[str] = None,
) -> None:
    """Call agent:run with key-pair JWT auth and stream the response."""
    url = (
        f"https://{account.strip()}.snowflakecomputing.com"
        f"/api/v2/databases/{database}/schemas/{schema}/agents/{agent_name}:run"
    )

    headers = _build_headers(jwt)
    if role:
        headers["X-Snowflake-Role"] = role
    if warehouse:
        headers["X-Snowflake-Warehouse"] = warehouse

    payload = {
        "thread_id": thread_id,
        "parent_message_id": 0,
        "messages": [{"role": "user", "content": [{"type": "text", "text": message}]}],
    }

    print(f"\n{'='*70}")
    print(f"Agent:  {database}.{schema}.{agent_name}")
    print(f"Auth:   Key-Pair JWT")
    if role:
        print(f"Role:   {role}")
    if warehouse:
        print(f"WH:     {warehouse}")
    print(f"Q:      {message}")
    print(f"{'='*70}\n")

    event_type = ""
    with requests.post(url, headers=headers, json=payload, stream=True) as resp:
        resp.raise_for_status()
        for line in resp.iter_lines():
            if not line:
                continue
            decoded = line.decode("utf-8")
            if decoded.startswith("event:"):
                event_type = decoded.split(":", 1)[1].strip()
            elif decoded.startswith("data:"):
                try:
                    data = json.loads(decoded.split(":", 1)[1].strip())
                    if event_type == "response.text.delta":
                        print(data.get("text", ""), end="", flush=True)
                    elif event_type == "error":
                        print(f"\n[ERROR] {data.get('message', 'Unknown')}")
                except json.JSONDecodeError:
                    pass
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    account = os.getenv("SNOWFLAKE_ACCOUNT")
    user = os.getenv("SNOWFLAKE_USER")
    key_path = os.getenv("SNOWFLAKE_PRIVATE_KEY_PATH")

    if not account or not user or not key_path:
        print("Required environment variables:")
        print("  SNOWFLAKE_ACCOUNT          e.g. myorg-myaccount")
        print("  SNOWFLAKE_USER             e.g. MY_SERVICE_USER")
        print("  SNOWFLAKE_PRIVATE_KEY_PATH e.g. ./rsa_key.pem")
        sys.exit(1)

    private_key_pem = open(key_path, "rb").read()

    print("Generating key-pair JWT...")
    jwt = get_jwt(account, user, private_key_pem)
    print("OK  JWT generated")

    print("Creating thread...")
    thread_id = create_thread(account, jwt)
    print(f"OK  Thread: {thread_id}")

    # --- Customize these to match your agent ---
    run_agent(
        account=account,
        jwt=jwt,
        database="MYDB",
        schema="MYSCHEMA",
        agent_name="my_agent",
        thread_id=thread_id,
        message="What were the top 5 products by revenue last month?",
        role="ANALYST_ROLE",
        warehouse="COMPUTE_WH",
    )


if __name__ == "__main__":
    main()
