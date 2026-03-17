"""
Baseline: call the Anthropic API directly.

This is the "before" code -- exactly what an existing Anthropic user runs today.
The next script (02_cortex_redirect.py) shows the same call routed through Cortex.

Prerequisites:
    export ANTHROPIC_API_KEY="sk-ant-..."  # pragma: allowlist secret
    pip install anthropic

Usage:
    python3 python/01_anthropic_direct.py
"""

import os
import sys

import anthropic

if not os.environ.get("ANTHROPIC_API_KEY"):
    print("ERROR: ANTHROPIC_API_KEY not set.")
    print("  export ANTHROPIC_API_KEY=\"sk-ant-...\"")
    sys.exit(1)

PROMPT = "Explain how a snowflake forms in exactly two sentences."

client = anthropic.Anthropic()

response = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=256,
    messages=[{"role": "user", "content": PROMPT}],
)

print("=== Anthropic Direct ===")
print(f"Model:    {response.model}")
print(f"Tokens:   {response.usage.input_tokens} in / {response.usage.output_tokens} out")
print(f"Response: {response.content[0].text}")
