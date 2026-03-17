---
name: cortex-anthropic-redirect
description: "Cortex Anthropic API redirect guide. Shows how to reroute Anthropic SDK calls to Snowflake Cortex REST API. Use when: anthropic migration, cortex messages api, api redirect, sdk base_url override."
---

# Cortex Anthropic API Redirect Guide

## Purpose
Show existing Anthropic API users how to redirect their Python SDK calls to Snowflake Cortex with 3 code changes, keeping the same request body and response format.

## Architecture
```
Anthropic Direct:   App --> anthropic SDK --> api.anthropic.com/v1/messages
Cortex Redirect:    App --> anthropic SDK --> <account>.snowflakecomputing.com/api/v2/cortex/v1/messages
                                              (base_url + Bearer auth override)
```
The SDK appends `/v1/messages` to the base_url automatically. Auth is swapped from `x-api-key` to `Authorization: Bearer <PAT>` via a custom httpx client.

## Key Files

| File | Role |
|------|------|
| `python/01_anthropic_direct.py` | Baseline Anthropic call (the "before") |
| `python/02_cortex_redirect.py` | Cortex-redirected call (the "after" -- 3 changes) |
| `python/03_side_by_side.py` | Runs both APIs, compares responses with timing |
| `python/04_streaming.py` | Streaming token-by-token comparison |
| `python/05_tool_calling.py` | Tool calling comparison with identical tool defs |
| `python/06_keypair_auth.py` | Production key-pair JWT auth example |
| `python/snowflake_auth.py` | Shared helper: builds Cortex client (PAT or key-pair JWT) |
| `curl_examples.sh` | Raw curl for both APIs |
| `requirements.txt` | anthropic, httpx, cryptography |
| `.env.example` | Credential template (PAT + key-pair variables) |

## Adding a New Comparison Example

1. Create `python/0N_<feature>.py` following the numbering convention
2. For Cortex client, use the shared helper: `from snowflake_auth import build_cortex_client_pat`
3. Build the Anthropic client: `anthropic.Anthropic()` (uses `ANTHROPIC_API_KEY` env var)
4. Make the same API call on both clients, print results
5. Add the script to README.md files table

## Snowflake Objects
- No Snowflake objects are created -- this is a client-side guide
- Requires: Snowflake account with Cortex REST API access + PAT (testing) or key-pair (production)

## Gotchas
- The httpx client override is mandatory -- without it the SDK sends `x-api-key` which Snowflake rejects
- `api_key="not-used"` is required because the SDK constructor validates a non-empty value  <!-- pragma: allowlist secret -->
- `default_headers` AND `http_client` headers must BOTH set the Bearer token (SDK uses different paths for different request types)
- Key-pair JWT requires `X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT` in BOTH httpx client and default_headers
- Key-pair JWT account identifier must be UPPERCASE with dots replaced by hyphens
- Model names are identical between Anthropic and Cortex (e.g., `claude-sonnet-4-5`)
- Cortex Messages API supports Claude models only; for other models use the Chat Completions API
