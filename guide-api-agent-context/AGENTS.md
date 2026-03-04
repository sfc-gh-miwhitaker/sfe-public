# API Agent Context Guide

Working examples of calling the Snowflake `agent:run` API with execution context
(role and warehouse) using three authentication methods: PAT, OAuth, and Key-Pair JWT.
Includes curl quick tests, Python scripts, Node.js examples, and a React integration guide.

## Project Structure
- `README.md` -- Quick Start, key concepts, auth comparison table
- `agent_run_with_context.py` -- Python examples with PAT, OAuth, and Key-Pair JWT auth + streaming
- `agent_run_keypair_jwt.py` -- Standalone Python key-pair JWT example (`cryptography` library)
- `agent_run_keypair_jwt.js` -- Standalone Node.js key-pair JWT example (zero dependencies, built-in `crypto`)
- `agent_run_react.md` -- React + Express integration guide with three backend proxy patterns
- `migrate_pat_to_keypair_jwt.md` -- Step-by-step migration recipes for switching existing projects to JWT

## Content Principles
- Practical examples first, theory second
- Four integration levels: curl, Python, Node.js, React
- Three auth methods: PAT (quick testing), OAuth (production SSO), Key-Pair JWT (service accounts)
- Both agent-object and inline-config API approaches
- Migration guide targets real projects (`demo-agent-multicontext`, `guide-agent-multi-tenant`)

## Auth Quick Reference

PAT:
```
Authorization: Bearer <pat_token>
```

OAuth:
```
Authorization: Bearer <oauth_access_token>
```

Key-Pair JWT:
```
Authorization: Bearer <jwt_token>
X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT
```

JWT issuer format: `ACCOUNT.USER.SHA256:<base64_sha256_fingerprint>`

## When Helping with This Project
- This is a guide, not a demo -- no deploy_all.sql, no expiration, no Snowflake objects
- The `agent:run` endpoint accepts `role` and `warehouse` via HTTP headers
- PAT auth header: `Authorization: Bearer <pat_token>`
- Key-pair JWT requires BOTH `Authorization: Bearer <jwt>` AND `X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT`
- JWT issuer claim format: `ACCOUNT.USER.SHA256:<fingerprint>` (all uppercase, dots replaced with hyphens in account)
- `agent_run_keypair_jwt.js` exports `getJwt()` and `buildHeaders()` for use as a module in other projects
- `migrate_pat_to_keypair_jwt.md` exists for users arriving from other projects needing JWT auth
- SSE streaming: parse `event:` lines for event type, `data:` lines for JSON payload
- Thread creation via `POST /api/v2/cortex/threads` for multi-turn conversations
- Python example uses `requests` with streaming; Node.js uses built-in `fetch`
- React guide uses Express backend proxy to keep credentials server-side

## Related Projects
- [`demo-agent-multicontext`](../demo-agent-multicontext/) -- runnable demo using the API patterns described here (per-request context injection)
- [`guide-agent-multi-tenant`](../guide-agent-multi-tenant/) -- production multi-tenant architecture using Azure AD OAuth + Row Access Policies
- [`demo-cortex-teams-agent`](../demo-cortex-teams-agent/) -- Teams / M365 Copilot integration with Cortex Agents

Consider these rules if they affect your changes.
