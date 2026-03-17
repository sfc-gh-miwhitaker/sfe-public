"""
Streaming comparison: token-by-token output from both APIs.

Shows that streaming works identically through Cortex.

Prerequisites:
    export ANTHROPIC_API_KEY="sk-ant-..."  # pragma: allowlist secret
    export SNOWFLAKE_ACCOUNT="myorg-myaccount"
    export SNOWFLAKE_PAT="ver:1:..."
    pip install anthropic httpx

Usage:
    python python/04_streaming.py
"""

import os
import time

import anthropic
import httpx

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
