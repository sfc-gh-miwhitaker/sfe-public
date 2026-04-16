"""
Shared helper: build an Anthropic client pointed at Snowflake Cortex.

Supports two auth methods:
  - PAT (quick testing)
  - Key-Pair JWT (production / service accounts)

Usage:
    from snowflake_auth import build_cortex_client_pat, build_cortex_client_keypair

See also:
    https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-rest-api
    https://docs.snowflake.com/en/user-guide/key-pair-auth
"""

import base64
import hashlib
import json
import math
import os
import time
from typing import Optional, Tuple

import anthropic
import httpx


# ---------------------------------------------------------------------------
# PAT client (simple)
# ---------------------------------------------------------------------------

def build_cortex_client_pat(
    account: Optional[str] = None,
    pat: Optional[str] = None,
) -> anthropic.Anthropic:
    """Build a Cortex-pointed Anthropic client using a PAT."""
    account = account or os.environ["SNOWFLAKE_ACCOUNT"]
    pat = pat or os.environ["SNOWFLAKE_PAT"]

    return anthropic.Anthropic(
        api_key="not-used",  # pragma: allowlist secret
        base_url=f"https://{account}.snowflakecomputing.com/api/v2/cortex",
        http_client=httpx.Client(headers={"Authorization": f"Bearer {pat}"}),
        default_headers={"Authorization": f"Bearer {pat}"},
    )


# ---------------------------------------------------------------------------
# Key-Pair JWT client (production)
# ---------------------------------------------------------------------------

def _base64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _normalize_account(account: str) -> str:
    """Snowflake JWT requires UPPERCASE with dots replaced by hyphens."""
    return (
        account.strip()
        .replace(".snowflakecomputing.com", "")
        .replace(".", "-")
        .upper()
    )


def _build_fingerprint(private_key_pem: bytes) -> str:
    """SHA256 fingerprint of the SPKI-encoded public key."""
    from cryptography.hazmat.primitives import serialization

    private_key = serialization.load_pem_private_key(private_key_pem, password=None)
    public_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    return base64.b64encode(hashlib.sha256(public_der).digest()).decode("ascii")


def generate_keypair_jwt(
    account: str,
    user: str,
    private_key_pem: bytes,
    expires_in_seconds: int = 3600,
) -> Tuple[str, int]:
    """Sign a Snowflake KEYPAIR_JWT. Returns (token, expiry_unix)."""
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    now = math.floor(time.time())
    exp = now + expires_in_seconds

    normalized = _normalize_account(account)
    qualified = f"{normalized}.{user.strip().upper()}"
    fingerprint = _build_fingerprint(private_key_pem)

    header = {"alg": "RS256", "typ": "JWT"}
    payload = {
        "iss": f"{qualified}.SHA256:{fingerprint}",
        "sub": qualified,
        "iat": now,
        "exp": exp,
    }

    signing_input = (
        f"{_base64url(json.dumps(header).encode())}"
        f".{_base64url(json.dumps(payload).encode())}"
    )

    private_key = serialization.load_pem_private_key(private_key_pem, password=None)
    signature = private_key.sign(
        signing_input.encode(),
        padding.PKCS1v15(),
        hashes.SHA256(),
    )

    return f"{signing_input}.{_base64url(signature)}", exp


_cached_jwt: Optional[str] = None
_cached_exp: int = 0


def get_jwt(account: str, user: str, private_key_pem: bytes) -> str:
    """Cached JWT -- auto-refreshes 5 minutes before expiry."""
    global _cached_jwt, _cached_exp
    now = math.floor(time.time())
    if _cached_jwt and (_cached_exp - 300) > now:
        return _cached_jwt
    _cached_jwt, _cached_exp = generate_keypair_jwt(account, user, private_key_pem)
    return _cached_jwt


def build_cortex_client_keypair(
    account: Optional[str] = None,
    user: Optional[str] = None,
    private_key_path: Optional[str] = None,
) -> anthropic.Anthropic:
    """Build a Cortex-pointed Anthropic client using key-pair JWT."""
    account = account or os.environ["SNOWFLAKE_ACCOUNT"]
    user = user or os.environ["SNOWFLAKE_USER"]
    key_path = private_key_path or os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]

    private_key_pem = open(key_path, "rb").read()
    jwt = get_jwt(account, user, private_key_pem)

    return anthropic.Anthropic(
        api_key="not-used",  # pragma: allowlist secret
        base_url=f"https://{account}.snowflakecomputing.com/api/v2/cortex",
        http_client=httpx.Client(
            headers={
                "Authorization": f"Bearer {jwt}",
                "X-Snowflake-Authorization-Token-Type": "KEYPAIR_JWT",
            },
        ),
        default_headers={
            "Authorization": f"Bearer {jwt}",
            "X-Snowflake-Authorization-Token-Type": "KEYPAIR_JWT",
        },
    )
