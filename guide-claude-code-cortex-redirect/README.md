![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2026--12--31-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Redirecting Claude Code Inference to Snowflake Cortex

How to point the `claude` CLI and Anthropic SDK clients at Snowflake's Cortex REST API instead of Anthropic directly — so all inference runs inside the Snowflake perimeter, billed and governed there.

**Audience:** Developers and IT admins deploying Claude Code with enterprise governance requirements
**Created:** 2026-07-08 | **Expires:** 2026-12-31 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production. This guide covers the Cortex REST API (GA) and the `claude` CLI redirect pattern (GA). Verify current model availability in your region before relying on a specific model name.

> **This is not the CoCo guide.** CoCo is Snowflake's own coding agent — it's Snowflake-native and the right tool if you're starting from scratch. This guide is for teams that *already have Claude Code deployed* and want to redirect its inference through Snowflake without switching agents. See [Connecting Claude to Snowflake](../guide-connecting-claude-snowflake/README.md) for the full surface comparison.

---

## What this does and why

By default, Claude Code sends every inference request to `api.anthropic.com`. Two env vars redirect that traffic to your Snowflake account instead:

```bash
export ANTHROPIC_BASE_URL="https://<account>.snowflakecomputing.com/api/v2/cortex"
export ANTHROPIC_AUTH_TOKEN="<your-snowflake-pat>"
```

**Why bother?**

| Concern | Default (Anthropic direct) | Via Snowflake Cortex |
|---------|---------------------------|----------------------|
| Data residency | Leaves your network to `api.anthropic.com` | Stays within Snowflake perimeter |
| Auth | Anthropic API key (separate credential) | Snowflake PAT / OAuth (existing credential) |
| Audit | Anthropic dashboard only | `CORTEX_REST_API_USAGE_HISTORY` in your account |
| Cost attribution | Anthropic invoice | Snowflake invoice, visible in ACCOUNT_USAGE |
| Access control | API key revocation | Snowflake RBAC (`CORTEX_USER` role) |
| Rate limits | Anthropic tier | Snowflake Cortex limits (6M TPM for sonnet-4-6) |

---

## Before you start

**Prerequisites:**
- A Snowflake account with Cortex enabled
- A Snowflake Programmatic Access Token (PAT) — or an OAuth token
- Claude Code CLI (`claude`) installed and working
- Your default Snowflake role must have `SNOWFLAKE.CORTEX_USER` (granted to PUBLIC by default; most users already have it)

**Find your account identifier:**

Your account identifier is the hostname prefix of your Snowflake URL. If you sign in at `<org>-<account>.snowflakecomputing.com`, your identifier is `<org>-<account>`.

For accounts with org-level URLs like `<myorg>-<myaccount>.snowflakecomputing.com`, the identifier is `<myorg>-<myaccount>`.

---

## Quick Start

Jump to the guide that matches your situation:

| I need to... | Guide |
|---|---|
| Redirect `claude` CLI for my own machine | [Claude Code CLI redirect](claude-code-redirect.md) |
| Choose the right auth method (PAT vs keychain vs JWT) | [Authentication Options](authentication.md) |
| Redirect an Anthropic SDK Python/Node app | [SDK redirect patterns](sdk-redirect.md) |
| Deploy the redirect policy across an org (IT admin) | [Org-wide enforcement](claude-code-redirect.md#org-wide-enforcement) |
| Verify traffic is actually hitting Snowflake | [Verification](claude-code-redirect.md#verification) |
| Understand what governance I get | [Governance](claude-code-redirect.md#governance) |

---

## Two API endpoints, one choice to make

Snowflake's Cortex REST API has two endpoints. Pick one:

| | Messages API | Chat Completions API |
|---|---|---|
| **Format** | Anthropic Messages spec | OpenAI Chat Completions spec |
| **Endpoint** | `/api/v2/cortex/v1/messages` | `/api/v2/cortex/v1/chat/completions` |
| **Models** | Claude only | All Cortex models |
| **SDK base URL** | `…/api/v2/cortex` | `…/api/v2/cortex/v1` |
| **Best for** | Existing Anthropic SDK code, Claude Code CLI | Multi-model apps, OpenAI SDK migration |
| **Auth header** | `Authorization: Bearer` (requires override) | `Authorization: Bearer` |

Claude Code uses the Anthropic SDK internally, so it routes through the **Messages API**. Most existing Anthropic SDK applications should also use the Messages API path. Switch to Chat Completions only if you want access to non-Claude models or prefer the OpenAI SDK interface.

---

## External References

- [Cortex REST API documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-rest-api)
- [Generating a Snowflake Programmatic Access Token (PAT)](https://docs.snowflake.com/en/user-guide/programmatic-access-tokens)
- [Authenticating Snowflake REST APIs](https://docs.snowflake.com/en/user-guide/snowflake-rest-api/authenticating)
- [Cortex REST API model availability by region](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-rest-api#model-availability)
- [CORTEX_REST_API_USAGE_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_rest_api_usage_history)
- [Snowflake + Anthropic $200M partnership](https://www.anthropic.com/news/snowflake-anthropic-expanded-partnership)

---

*Pair-programmed by SE Community + Cortex Code*
