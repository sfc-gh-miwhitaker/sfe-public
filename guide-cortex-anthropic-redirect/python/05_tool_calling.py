"""
Tool calling comparison: identical tool definitions on both APIs.

Demonstrates that Cortex handles the full tool-use round trip:
  1. Send request with tools
  2. Model returns tool_use block
  3. Send tool result back
  4. Model generates final response

Prerequisites:
    export ANTHROPIC_API_KEY="sk-ant-..."  # pragma: allowlist secret
    export SNOWFLAKE_ACCOUNT="myorg-myaccount"
    export SNOWFLAKE_PAT="ver:1:..."
    pip install anthropic httpx

Usage:
    python3 python/05_tool_calling.py
"""

import json
import os
import sys

import anthropic
import httpx

missing = [v for v in ("ANTHROPIC_API_KEY", "SNOWFLAKE_ACCOUNT", "SNOWFLAKE_PAT") if not os.environ.get(v)]
if missing:
    print(f"ERROR: Missing environment variable(s): {', '.join(missing)}")
    print("  See .env.example for the full list.")
    sys.exit(1)

ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]
PAT = os.environ["SNOWFLAKE_PAT"]
MODEL = "claude-sonnet-4-5"
MAX_TOKENS = 1024

TOOLS = [
    {
        "name": "get_weather",
        "description": "Get the current weather for a location",
        "input_schema": {
            "type": "object",
            "properties": {
                "location": {
                    "type": "string",
                    "description": "City and state, e.g. San Francisco, CA",
                }
            },
            "required": ["location"],
        },
    }
]

PROMPT = "What is the weather like in San Francisco?"


def build_anthropic_client():
    return anthropic.Anthropic()


def build_cortex_client():
    return anthropic.Anthropic(
        api_key="not-used",  # pragma: allowlist secret
        base_url=f"https://{ACCOUNT}.snowflakecomputing.com/api/v2/cortex",
        http_client=httpx.Client(headers={"Authorization": f"Bearer {PAT}"}),
        default_headers={"Authorization": f"Bearer {PAT}"},
    )


def simulate_tool(name, input_args):
    """Simulate the tool execution (same for both APIs)."""
    if name == "get_weather":
        return json.dumps({
            "temperature": "68°F",
            "condition": "sunny",
            "location": input_args.get("location", "unknown"),
        })
    return json.dumps({"error": "unknown tool"})


def run_tool_calling(client, label):
    print(f"\n{'=' * 60}")
    print(f"  {label}")
    print(f"{'=' * 60}")

    messages = [{"role": "user", "content": PROMPT}]

    response = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        messages=messages,
        tools=TOOLS,
    )

    print(f"  Step 1 - Stop reason: {response.stop_reason}")

    if response.stop_reason != "tool_use":
        print(f"  Model did not request a tool. Response: {response.content[0].text}")
        return

    tool_use = next(b for b in response.content if b.type == "tool_use")
    print(f"  Step 2 - Tool called: {tool_use.name}({json.dumps(tool_use.input)})")

    tool_result = simulate_tool(tool_use.name, tool_use.input)
    print(f"  Step 3 - Tool result: {tool_result}")

    messages.append({"role": "assistant", "content": response.content})
    messages.append({
        "role": "user",
        "content": [
            {
                "type": "tool_result",
                "tool_use_id": tool_use.id,
                "content": tool_result,
            }
        ],
    })

    final = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        messages=messages,
        tools=TOOLS,
    )

    print(f"  Step 4 - Final response: {final.content[0].text}")


print(f"Prompt: {PROMPT}")
print(f"Tool:   get_weather (simulated)")

run_tool_calling(build_anthropic_client(), "Anthropic Direct")
run_tool_calling(build_cortex_client(), "Cortex Redirect")

print(f"\n{'─' * 60}")
print("Tool definitions, request format, and response format were identical.")
