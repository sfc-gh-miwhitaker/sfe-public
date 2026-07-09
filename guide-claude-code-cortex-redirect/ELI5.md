> Simplified from: guide-claude-code-cortex-redirect/README.md

## One-Sentence Version

Two environment variables redirect Claude Code's inference traffic from Anthropic's servers to your Snowflake account — so all AI calls stay inside your perimeter, show up on your Snowflake bill, and follow your existing access controls.

## The Story (analogy-driven)

Imagine your team uses a delivery service (Claude Code) that normally sends packages through a public carrier (Anthropic's API). The packages contain your questions and get answers back. They work fine, but they leave your building, travel across town, and come back — and you get a separate invoice from the carrier.

This guide shows you how to reroute the delivery truck so it never leaves your building. You set up a mailroom inside your own office (Snowflake Cortex), and tell the delivery service "use our internal mailroom instead." Same packages, same answers — but now they never leave, they show up on your existing building bill, and your security team can see every delivery in the building's log.

The setup is two lines in your terminal: one tells Claude Code where to deliver (your Snowflake URL) and one provides the building access badge (your Snowflake token).

## The Cast (concept glossary)

- **ANTHROPIC_BASE_URL** — The environment variable that tells Claude Code where to send inference requests (redirected to your Snowflake account).
- **ANTHROPIC_AUTH_TOKEN** — The environment variable holding your Snowflake credential (a PAT or OAuth token). Note: it's AUTH_TOKEN, not API_KEY — using the wrong variable name is a common mistake.
- **Cortex REST API** — Snowflake's endpoint that speaks the same language as Anthropic's API, so Claude Code doesn't know the difference.
- **Messages API** — The Anthropic-format endpoint at `/api/v2/cortex/v1/messages` that Claude Code uses.
- **PAT** — Programmatic Access Token; a credential you generate in Snowflake that doesn't expire on browser session.

## What Changed

- Before: Claude Code sent all inference to `api.anthropic.com`. Data left your network. Costs appeared on a separate Anthropic invoice. Audit was limited to Anthropic's dashboard.
- After: inference stays within Snowflake. Costs appear in `CORTEX_REST_API_USAGE_HISTORY`. Access is governed by your existing Snowflake RBAC. No separate credential management.

## What to Watch Out For

- Use `ANTHROPIC_AUTH_TOKEN`, not `ANTHROPIC_API_KEY`. The wrong variable name is the most common setup failure — Claude Code will silently try to authenticate to Snowflake with an Anthropic key format and fail.
- The Messages API base URL is `/api/v2/cortex` (no `/v1` suffix in the base). The SDK appends `/v1/messages` itself.
- Model availability varies by region. If your model isn't in your region, enable cross-region inference or you'll get errors.
- Rate limits are Snowflake's limits (e.g., 6M tokens per minute for sonnet-4-6), not Anthropic's tier limits.

## The One Thing to Remember

It's two environment variables — `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` — and your Claude Code traffic never leaves Snowflake again.

> For the full technical details, see the source document.
