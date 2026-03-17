"""
Production auth: Cortex redirect using key-pair JWT instead of PAT.

Key-pair JWT is the recommended auth for:
  - Service accounts (no human login)
  - CI/CD pipelines
  - Long-running backend services
  - Environments with no-password security policies

One-time setup:
    # 1. Generate RSA key pair
    openssl genrsa -out rsa_key.pem 2048
    openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub

    # 2. Get public key content (strip header/footer)
    grep -v "BEGIN\\|END" rsa_key.pub | tr -d '\\n'

    # 3. Assign to Snowflake user (run as ACCOUNTADMIN)
    ALTER USER MY_SERVICE_USER SET RSA_PUBLIC_KEY='MIIBIjANBgkqhki...';

Prerequisites:
    cp .env.example .env   # fill in your credentials
    pip3 install -r requirements.txt

Usage:
    python3 python/06_keypair_auth.py
"""

import os
import sys

from dotenv import load_dotenv

load_dotenv()

missing = [v for v in ("SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_PRIVATE_KEY_PATH") if not os.environ.get(v)]
if missing:
    print(f"ERROR: Missing environment variable(s): {', '.join(missing)}")
    print("  Add them to your .env file or export manually.")
    sys.exit(1)

from snowflake_auth import build_cortex_client_keypair

PROMPT = "Explain how a snowflake forms in exactly two sentences."

client = build_cortex_client_keypair()

response = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=256,
    messages=[{"role": "user", "content": PROMPT}],
)

print("=== Cortex via Key-Pair JWT ===")
print(f"Model:    {response.model}")
print(f"Tokens:   {response.usage.input_tokens} in / {response.usage.output_tokens} out")
print(f"Response: {response.content[0].text}")
