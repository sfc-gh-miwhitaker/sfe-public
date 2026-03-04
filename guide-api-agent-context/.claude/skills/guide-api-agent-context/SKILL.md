---
name: guide-api-agent-context
description: "Snowflake agent:run API examples with PAT, OAuth, and Key-Pair JWT auth. Triggers: agent:run API, execution context, key-pair JWT, PAT auth, OAuth agent, migrate PAT to JWT, agent authentication, Express proxy agent, KEYPAIR_JWT header, agent REST API."
---

# API Agent Context Guide

## Purpose

Code snippet guide for calling the Snowflake `agent:run` API with execution context (role, warehouse) using three authentication methods. Covers curl, Python, Node.js, and React integration levels. Includes a migration guide for switching existing projects from PAT to key-pair JWT.

## When to Use

- Adding authentication to an agent project
- Switching from PAT to key-pair JWT auth
- Understanding the `agent:run` API request/response format
- Building an Express or Python backend proxy for Cortex Agents
- Setting role and warehouse context via HTTP headers

## Architecture

```
Three Auth Paths
  PAT ──────────────> Authorization: Bearer <pat>
  OAuth ────────────> Authorization: Bearer <oauth_token>
  Key-Pair JWT ─────> Authorization: Bearer <jwt>
                      + X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT

Four Integration Levels
  curl ──────> README.md quick test
  Python ────> agent_run_with_context.py (all 3 auth methods)
               agent_run_keypair_jwt.py  (JWT standalone)
  Node.js ───> agent_run_keypair_jwt.js  (JWT standalone, zero deps)
  React ─────> agent_run_react.md        (3 backend proxy patterns)

Migration
  PAT → JWT ─> migrate_pat_to_keypair_jwt.md (recipes for real projects)
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Quick start, auth comparison table, key concepts, related projects |
| `agent_run_with_context.py` | Python examples with all 3 auth methods, both API approaches, SSE streaming |
| `agent_run_keypair_jwt.py` | Standalone Python JWT: key loading, fingerprint, RS256 signing, token cache |
| `agent_run_keypair_jwt.js` | Standalone Node.js JWT: same logic, built-in `crypto`, exports `getJwt()` + `buildHeaders()` |
| `agent_run_react.md` | React + Express guide: PAT proxy, OAuth direct, key-pair JWT proxy |
| `migrate_pat_to_keypair_jwt.md` | Step-by-step recipes targeting `demo-agent-multicontext` and `guide-agent-multi-tenant` |
| `AGENTS.md` | Project instructions for AI assistants |

## Auth Quick Reference

**PAT:**
```
Authorization: Bearer <pat_token>
```

**OAuth:**
```
Authorization: Bearer <oauth_access_token>
```

**Key-Pair JWT:**
```
Authorization: Bearer <jwt_token>
X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT
```

JWT issuer: `ACCOUNT.USER.SHA256:<base64_sha256_fingerprint>` (account uppercase, dots→hyphens)

## Extension Playbook: Adding Key-Pair JWT to an Existing Project

1. Generate RSA key pair: `openssl genrsa -out rsa_key.pem 2048`
2. Assign public key: `ALTER USER <user> SET RSA_PUBLIC_KEY='...';`
3. Copy `agent_run_keypair_jwt.js` (or `.py`) into your project
4. Replace PAT env vars with `SNOWFLAKE_USER` + `SNOWFLAKE_PRIVATE_KEY_PATH`
5. Replace `Authorization: Bearer ${PAT}` with `getJwt()` + `buildHeaders()`
6. Full walkthrough: `migrate_pat_to_keypair_jwt.md`

## Related Projects

- [`demo-agent-multicontext`](../../../demo-agent-multicontext/) -- runnable demo using the API patterns here
- [`guide-agent-multi-tenant`](../../../guide-agent-multi-tenant/) -- production multi-tenant with Azure AD OAuth + RAPs
- [`demo-cortex-teams-agent`](../../../demo-cortex-teams-agent/) -- Teams / M365 Copilot integration

## Gotchas

- Key-pair JWT requires BOTH the `Authorization` header AND `X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT`
- Account identifier in JWT must be UPPERCASE with dots replaced by hyphens
- The `.js` module exports `getJwt()` and `buildHeaders()` for drop-in use in Express projects
- Token cache refreshes 5 minutes before expiry (1-hour default lifetime)
- `agent_run_with_context.py` returns `(token, extra_headers)` tuple -- callers must spread `extra_headers` into all requests
- This is a guide, not a demo -- no Snowflake objects, no deploy/teardown scripts
