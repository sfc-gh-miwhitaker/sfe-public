"""
Streaming comparison: token-by-token output from both APIs.

Shows that streaming works identically through Cortex.

Prerequisites:
    cp .env.example .env   # fill in your credentials
    pip3 install -r requirements.txt

Usage:
    python3 python/04_streaming.py
"""

import os
import sys
import time

from dotenv import load_dotenv

load_dotenv()

import anthropic
import httpx

missing = [v for v in ("ANTHROPIC_API_KEY", "SNOWFLAKE_ACCOUNT", "SNOWFLAKE_PAT") if not os.environ.get(v)]
if missing:
    print(f"ERROR: Missing environment variable(s): {', '.join(missing)}")
    print("  Add them to your .env file or export manually.")
    sys.exit(1)

PROMPT = "Write a haiku about data governance."

ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]
PAT = os.environ["SNOWFLAKE_PAT"]
MODEL = "claude-sonnet-4-5"
MAX_TOKENS = 256


def build_anthropic_client():
    return anthropic.Anthropic()


def build_cortex_client():
    return anthropic.Anthropic(
        api_key="not-used",  # pragma: allowlist secret
        base_url=f"https://{ACCOUNT}.snowflakecomputing.com/api/v2/cortex",
        http_client=httpx.Client(headers={"Authorization": f"Bearer {PAT}"}),
        default_headers={"Authorization": f"Bearer {PAT}"},
    )


def stream_response(client, label):
    print(f"\n{'=' * 50}")
    print(f"  {label} (streaming)")
    print(f"{'=' * 50}")

    start = time.perf_counter()
    with client.messages.stream(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        messages=[{"role": "user", "content": PROMPT}],
    ) as stream:
        for text in stream.text_stream:
            print(text, end="", flush=True)

    elapsed = time.perf_counter() - start
    print(f"\n  [{elapsed:.2f}s]")


print(f"Prompt: {PROMPT}")

stream_response(build_anthropic_client(), "Anthropic Direct")
stream_response(build_cortex_client(), "Cortex Redirect")

print(f"\n{'─' * 50}")
print("Both streams used identical client.messages.stream() calls.")
