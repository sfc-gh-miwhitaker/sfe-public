# Cortex Anthropic API Redirect Guide

Show existing Anthropic API users how to redirect their SDK calls to Snowflake Cortex
with minimal code changes -- runnable Python scripts that call both APIs side by side.

## Project Structure
- `README.md` -- Migration guide, quick start, feature compatibility matrix
- `python/01_anthropic_direct.py` -- Baseline: standard Anthropic SDK call
- `python/02_cortex_redirect.py` -- Same call redirected to Cortex (3 changes)
- `python/03_side_by_side.py` -- Runs both APIs, compares responses with timing
- `python/04_streaming.py` -- Streaming comparison
- `python/05_tool_calling.py` -- Tool calling comparison
- `python/06_keypair_auth.py` -- Production key-pair JWT auth
- `python/snowflake_auth.py` -- Shared helper: builds Cortex client (PAT or key-pair JWT)
- `claude-code-jwt-helper.sh` -- apiKeyHelper script for Claude Code key-pair JWT auth
- `curl_examples.sh` -- Raw curl equivalents for both APIs
- `.claude/skills/cortex-anthropic-redirect/SKILL.md` -- Project-specific AI skill

## Key Technical Details
- Cortex Messages API base_url: `https://<account>.snowflakecomputing.com/api/v2/cortex`
- Anthropic SDK sends `x-api-key` by default; Snowflake expects `Bearer` token
- Must override auth with custom httpx client AND `default_headers`
- `api_key="not-used"` is required (SDK mandates a value but Cortex ignores it)  <!-- pragma: allowlist secret -->
- Request body, model names, and response format are identical between both APIs
- Two auth methods: PAT (testing) and key-pair JWT (production)
- Key-pair JWT requires extra header: `X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT`
- `python/snowflake_auth.py` provides `build_cortex_client_pat()` and `build_cortex_client_keypair()`
- Claude Code redirect uses `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` env vars (same base_url, different auth mechanism)
- Claude Code key-pair JWT uses `apiKeyHelper` setting pointing to `claude-code-jwt-helper.sh`

## When Helping with This Project
- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects
- All scripts load credentials from environment variables (never hardcoded)
- The `.env.example` shows the required variables; users copy to `.env`
- Each Python script is self-contained and independently runnable
- The `03_side_by_side.py` script is the best one for live demos
- Cortex Messages API supports: streaming, tool calling, structured output, thinking, image input, prompt caching
- The guide covers two redirect targets: the Anthropic Python SDK (code changes) and Claude Code (env var changes)

## Helping New Users

If the user seems confused or asks basic questions:

1. **Explain the concept** -- this guide shows how to take existing Anthropic API code and route it through Snowflake Cortex instead, keeping data within Snowflake's governance boundary
2. **Check prerequisites** -- they need an Anthropic API key AND a Snowflake PAT
3. **Start simple** -- run `01_anthropic_direct.py` first to verify Anthropic access works, then `02_cortex_redirect.py` to verify Cortex access
4. **Show the comparison** -- `03_side_by_side.py` is the "wow" moment

## Cost & Value Narrative

The README includes a balanced "When to Use Which" comparison. Key points to know:

**When Anthropic Direct wins:**
- High-volume batch processing (50% discount via Batch API)
- Aggressive prompt caching (90% discount on cache hits)
- Pure cost optimization when governance isn't required

**When Cortex wins:**
- Data governance requirements (data stays in Snowflake)
- Agent workloads (built-in Agent Evaluations saves weeks of build time)
- Unified billing, cost controls, and observability

**Be honest:** Don't oversell Cortex. If someone is doing batch text processing with no governance needs, Anthropic direct is likely cheaper. If they're building agents or need compliance, Cortex adds significant value beyond token pricing.

## Related Projects
- [`tool-cortex-rest-api-cost`](../tool-cortex-rest-api-cost/) -- Track the dollar cost of REST API calls this guide generates
- [`tool-cortex-cost-intelligence`](../tool-cortex-cost-intelligence/) -- Broader Cortex cost governance platform
- [`guide-api-agent-context`](../guide-api-agent-context/) -- Agent:Run REST API examples with three auth methods
- [`tool-secrets-rotation-aws`](../tool-secrets-rotation-aws/) -- PAT credential rotation patterns
