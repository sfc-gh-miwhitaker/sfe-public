# Anthropic SDK Redirect Patterns

How to redirect `anthropic` and `openai` SDK clients to Snowflake Cortex instead of hitting Anthropic or OpenAI directly.

> **Model selection:** Never hardcode a model string in your code. Read it from `ANTHROPIC_MODEL` (the same env var the CLI uses) so you can swap models without touching code. Set a sensible default for local dev — `claude-sonnet-4-6` is a good GA choice — but let the env override it.

---

## Choosing an endpoint

Two endpoints are available. Pick based on your existing code:

| | Messages API | Chat Completions API |
|---|---|---|
| **Use if you have** | `anthropic.Anthropic()` or `anthropic.AsyncAnthropic()` | `openai.OpenAI()` or `openai.AsyncOpenAI()` |
| **SDK base URL** | `https://<account>.snowflakecomputing.com/api/v2/cortex` | `https://<account>.snowflakecomputing.com/api/v2/cortex/v1` |
| **Models** | Claude only | All Cortex models (Claude, OpenAI, Llama, Mistral, etc.) |
| **Auth header sent by default** | `x-api-key` — **Snowflake rejects this** | `Authorization: Bearer` — Snowflake accepts this |

The Messages API requires overriding the auth header (the Anthropic SDK sends `x-api-key` by default; Snowflake needs `Authorization: Bearer`). The Chat Completions API via the OpenAI SDK uses the right header automatically.

---

## Messages API — Python (anthropic SDK)

The Anthropic SDK sends `x-api-key` by default. Override it with a custom `httpx.Client`:

```python
import os
import httpx
import anthropic

PAT     = os.environ["SNOWFLAKE_PAT"]
ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]   # e.g., "orgname-account"
MODEL   = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-6")

http_client = httpx.Client(
    headers={"Authorization": f"Bearer {PAT}"},
)

client = anthropic.Anthropic(
    api_key="placeholder",  # pragma: allowlist secret
    base_url=f"https://{ACCOUNT}.snowflakecomputing.com/api/v2/cortex",
    http_client=http_client,
    default_headers={"Authorization": f"Bearer {PAT}"},
)

response = client.messages.create(
    model=MODEL,
    max_tokens=1024,
    messages=[{"role": "user", "content": "Explain Snowflake's zero-copy cloning in one paragraph."}],
)

print(response.content[0].text)
```

**Async version:**

```python
import asyncio
import os
import httpx
import anthropic

PAT     = os.environ["SNOWFLAKE_PAT"]
ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]
MODEL   = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-6")

async def main():
    async with httpx.AsyncClient(headers={"Authorization": f"Bearer {PAT}"}) as http_client:
        client = anthropic.AsyncAnthropic(
            api_key="placeholder",  # pragma: allowlist secret
            base_url=f"https://{ACCOUNT}.snowflakecomputing.com/api/v2/cortex",
            http_client=http_client,
            default_headers={"Authorization": f"Bearer {PAT}"},
        )

        response = await client.messages.create(
            model=MODEL,
            max_tokens=1024,
            messages=[{"role": "user", "content": "What is Snowflake Cortex?"}],
        )

        print(response.content[0].text)

asyncio.run(main())
```

**Streaming:**

```python
with client.messages.stream(
    model=MODEL,
    max_tokens=1024,
    messages=[{"role": "user", "content": "Walk me through this codebase step by step."}],
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
```

---

## Messages API — Node.js (anthropic SDK)

```typescript
import Anthropic from "@anthropic-ai/sdk";

const PAT     = process.env.SNOWFLAKE_PAT!;
const ACCOUNT = process.env.SNOWFLAKE_ACCOUNT!;
const MODEL   = process.env.ANTHROPIC_MODEL ?? "claude-sonnet-4-6";

const client = new Anthropic({
  apiKey: "placeholder",  // pragma: allowlist secret
  baseURL: `https://${ACCOUNT}.snowflakecomputing.com/api/v2/cortex`,
  defaultHeaders: {
    Authorization: `Bearer ${PAT}`,
  },
});

const response = await client.messages.create({
  model: MODEL,
  max_tokens: 1024,
  messages: [{ role: "user", content: "Explain Snowflake's zero-copy cloning." }],
});

console.log(response.content[0].text);
```

**Streaming:**

```typescript
const stream = client.messages.stream({
  model: MODEL,
  max_tokens: 1024,
  messages: [{ role: "user", content: "Walk me through this codebase." }],
});

for await (const event of stream) {
  if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
    process.stdout.write(event.delta.text);
  }
}
```

---

## Chat Completions API — Python (openai SDK)

No auth header override needed — the OpenAI SDK sends `Authorization: Bearer` correctly:

```python
import os
from openai import OpenAI

MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-6")

client = OpenAI(
    api_key=os.environ["SNOWFLAKE_PAT"],
    base_url=f"https://{os.environ['SNOWFLAKE_ACCOUNT']}.snowflakecomputing.com/api/v2/cortex/v1",
)

response = client.chat.completions.create(
    model=MODEL,
    messages=[
        {"role": "system", "content": "You are a helpful data engineering assistant."},
        {"role": "user", "content": "Write a Snowflake dynamic table for daily sales aggregation."},
    ],
)

print(response.choices[0].message.content)
```

**Why use Chat Completions instead of Messages API?**

- You're already using the OpenAI SDK and don't want to switch
- You want access to non-Claude models (Llama, Mistral, DeepSeek, etc.) in the same codebase
- Simpler auth (no httpx override needed)
- The tradeoff: some Claude-specific features (adaptive thinking, beta headers) are only available through the Messages API

**Streaming:**

```python
stream = client.chat.completions.create(
    model=MODEL,
    messages=[{"role": "user", "content": "Explain column masking policies."}],
    stream=True,
)
for chunk in stream:
    print(chunk.choices[0].delta.content or "", end="", flush=True)
```

---

## Chat Completions API — Node.js (openai SDK)

```typescript
import OpenAI from "openai";

const MODEL = process.env.ANTHROPIC_MODEL ?? "claude-sonnet-4-6";

const client = new OpenAI({
  apiKey: process.env.SNOWFLAKE_PAT!,
  baseURL: `https://${process.env.SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/v1`,
});

const response = await client.chat.completions.create({
  model: MODEL,
  messages: [
    { role: "user", content: "Write a Snowflake stored procedure for data quality checks." },
  ],
});

console.log(response.choices[0].message.content);
```

---

## Full environment variable setup

Configure endpoint, auth, and model together — nothing hardcoded:

```bash
export ANTHROPIC_BASE_URL="https://<account>.snowflakecomputing.com/api/v2/cortex"
export ANTHROPIC_AUTH_TOKEN="<your-snowflake-pat>"
export ANTHROPIC_MODEL="claude-sonnet-4-6"   # swap without touching code
```

With these set, the SDK can be initialized without explicit config, and model selection is a deploy-time or shell decision rather than a code change:

```python
import os
import anthropic

MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-6")

# SDK reads ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN from env
client = anthropic.Anthropic(api_key="placeholder")  # pragma: allowlist secret

response = client.messages.create(
    model=MODEL,
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello"}],
)
```

> **Note:** Even with `ANTHROPIC_AUTH_TOKEN` set, the default `httpx.Client` may still include an `x-api-key` header (set to `placeholder`) alongside the Bearer token. Snowflake ignores the `x-api-key` header and uses the `Authorization: Bearer` token. In practice this works correctly, but to be precise, pass a custom `http_client` as shown in the explicit examples above.

---

## Verify your SDK calls are reaching Snowflake

After making a test call, query `CORTEX_REST_API_USAGE_HISTORY` in Snowflake:

```sql
SELECT
    start_time,
    model_name,
    user_id,
    tokens_granular:"input"::INT  AS input_tokens,
    tokens_granular:"output"::INT AS output_tokens,
    inference_region
FROM snowflake.account_usage.cortex_rest_api_usage_history
WHERE start_time >= DATEADD('minute', -10, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 10;
```

If your call appears here, the redirect is working. Note up to 45 minutes of latency in this view.

---

## Feature parity notes

Features supported via Cortex REST API that work the same as Anthropic direct:

- Streaming (`stream=True` / `stream: true`)
- Tool calling / function calling
- Structured output (`json_schema` response format)
- Vision / image input (Claude models: sonnet-4-5 and newer)
- Prompt caching (`cache_control` on content blocks; 5-minute TTL, max 4 breakpoints)
- Adaptive thinking (`thinking: {type: "adaptive"}` in Messages API)
- Beta features via `anthropic-beta` header (Bedrock-compatible headers only)

Features **not** supported via Cortex REST API:

- Audio input/output
- Anthropic-specific beta headers that are not Bedrock-compatible
- `service_tier` (flex processing / priority routing)
- OpenAI-specific fields like `logprobs`, `frequency_penalty`, `presence_penalty` (for Claude models)
- `x-ratelimit-*` response headers (Snowflake does not return these)
