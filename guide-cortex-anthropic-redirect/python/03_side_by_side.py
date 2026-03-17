"""
Side-by-side comparison: same prompt, both APIs, with timing.

Best script for live demos -- visually proves identical behavior.

Prerequisites:
    export ANTHROPIC_API_KEY="sk-ant-..."  # pragma: allowlist secret
    export SNOWFLAKE_ACCOUNT="myorg-myaccount"
    export SNOWFLAKE_PAT="ver:1:..."
    pip install anthropic httpx

Usage:
    python python/03_side_by_side.py
"""

import os
import time

import anthropic
import httpx

PROMPT = "Name the three largest oceans by area and give each one's approximate size in square kilometers. Reply in a markdown table."

ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]
PAT = os.environ["SNOWFLAKE_PAT"]
MODEL = "claude-sonnet-4-5"
MAX_TOKENS = 512


def build_anthropic_client():
    return anthropic.Anthropic()


def build_cortex_client():
    return anthropic.Anthropic(
        api_key="not-used",  # pragma: allowlist secret
        base_url=f"https://{ACCOUNT}.snowflakecomputing.com/api/v2/cortex",
        http_client=httpx.Client(headers={"Authorization": f"Bearer {PAT}"}),
        default_headers={"Authorization": f"Bearer {PAT}"},
    )


def call(client, label):
    start = time.perf_counter()
    response = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        messages=[{"role": "user", "content": PROMPT}],
    )
    elapsed = time.perf_counter() - start
    return {
        "label": label,
        "model": response.model,
        "text": response.content[0].text,
        "input_tokens": response.usage.input_tokens,
        "output_tokens": response.usage.output_tokens,
        "elapsed_s": round(elapsed, 2),
    }


def print_result(r):
    print(f"\n{'=' * 60}")
    print(f"  {r['label']}")
    print(f"{'=' * 60}")
    print(f"  Model:   {r['model']}")
    print(f"  Tokens:  {r['input_tokens']} in / {r['output_tokens']} out")
    print(f"  Time:    {r['elapsed_s']}s")
    print(f"{'─' * 60}")
    print(r["text"])


print(f"Prompt: {PROMPT}\n")
print("Calling Anthropic direct...")
anthropic_result = call(build_anthropic_client(), "Anthropic Direct (api.anthropic.com)")

print("Calling Cortex redirect...")
cortex_result = call(build_cortex_client(), f"Cortex Redirect ({ACCOUNT}.snowflakecomputing.com)")

print_result(anthropic_result)
print_result(cortex_result)

print(f"\n{'=' * 60}")
print("  Summary")
print(f"{'=' * 60}")
print(f"  Both APIs used model: {anthropic_result['model']} / {cortex_result['model']}")
print(f"  Anthropic: {anthropic_result['elapsed_s']}s | Cortex: {cortex_result['elapsed_s']}s")
print(f"  Request body was identical -- only the client setup differs.")
