"""
Same call as 01_anthropic_direct.py, redirected to Snowflake Cortex.

Three changes from the baseline:
  1. base_url    -> your Snowflake account's Cortex endpoint
  2. api_key     -> "not-used" (SDK requires a value; Cortex ignores it)
  3. auth header -> Bearer PAT via httpx client + default_headers

Everything after client creation is identical.

Prerequisites:
    export SNOWFLAKE_ACCOUNT="myorg-myaccount"
    export SNOWFLAKE_PAT="ver:1:..."
    pip install anthropic httpx

Usage:
    python3 python/02_cortex_redirect.py
"""

import os
import sys

import anthropic
import httpx

missing = [v for v in ("SNOWFLAKE_ACCOUNT", "SNOWFLAKE_PAT") if not os.environ.get(v)]
if missing:
    print(f"ERROR: Missing environment variable(s): {', '.join(missing)}")
    print("  export SNOWFLAKE_ACCOUNT=\"myorg-myaccount\"")
    print("  export SNOWFLAKE_PAT=\"ver:1:...\"")
    sys.exit(1)

PROMPT = "Explain how a snowflake forms in exactly two sentences."

ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]
PAT = os.environ["SNOWFLAKE_PAT"]

# --- THE 3-LINE CHANGE ---
client = anthropic.Anthropic(
    api_key="not-used",  # pragma: allowlist secret
    base_url=f"https://{ACCOUNT}.snowflakecomputing.com/api/v2/cortex",
    http_client=httpx.Client(headers={"Authorization": f"Bearer {PAT}"}),
    default_headers={"Authorization": f"Bearer {PAT}"},
)
# --- EVERYTHING BELOW IS IDENTICAL ---

response = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=256,
    messages=[{"role": "user", "content": PROMPT}],
)

print("=== Cortex Redirect ===")
print(f"Model:    {response.model}")
print(f"Tokens:   {response.usage.input_tokens} in / {response.usage.output_tokens} out")
print(f"Response: {response.content[0].text}")
