---
name: tool-cortex-agent-chat
description: "React chat interface for Snowflake Cortex Agents with key-pair JWT auth. Triggers: cortex agent chat, react agent UI, agent REST API, key pair JWT, agent:run streaming, SSE agent response, express proxy agent."
---

# Cortex Agent Chat - React Integration

## Purpose

React.js chat interface with Express backend proxy for Snowflake Cortex Agents. Uses key-pair JWT authentication, SSE streaming for real-time responses, and thread management for conversation continuity.

## When to Use

- Building or modifying the React chat UI
- Debugging JWT authentication or SSE streaming
- Extending the agent with new tools
- Adapting the pattern for a different frontend framework

## Architecture

```
React Frontend (Vite)
  ├── ChatInterface (messages, input, config)
  ├── ConfigPanel (account, agent, model settings)
  └── snowflakeApi.js (SSE streaming client)
       │
       ▼
Express Backend Proxy (server/index.js)
  ├── JWT signing (Node.js crypto, RSA key-pair)
  ├── /api/agent-query (POST → agent:run)
  └── /api/create-thread (POST → threads)
       │
       ▼
Snowflake Cortex Agent REST API
  ├── POST /api/v2/cortex/agent:run
  └── POST /api/v2/cortex/agent:create-thread
```

## Key Files

| File | Purpose |
|------|---------|
| `deploy.sql` | CREATE AGENT DDL with YAML spec |
| `server/index.js` | Express proxy, JWT crypto, SSE forwarding |
| `src/services/snowflakeApi.js` | Frontend API client, SSE delta parsing |
| `src/components/ChatInterface.jsx` | Main chat component |
| `src/components/ConfigPanel.jsx` | Runtime configuration panel |
| `src/App.js` | Config state, env var auto-detection |
| `tools/01_setup.sh` | RSA key generation, SQL template, .env creation |

## JWT Authentication Pattern

```javascript
const privateKey = fs.readFileSync(keyPath, 'utf8');
const payload = {
  iss: `${account}.${user}.SHA256:${publicKeyFingerprint}`,
  sub: `${account}.${user}`,
  iat: now, exp: now + 3600
};
const token = crypto.sign('RSA-SHA256', Buffer.from(headerPayload), privateKey);
```

## Agent Spec Pattern

```yaml
models:
  orchestration: auto       # ALWAYS auto
orchestration:
  budget:
    seconds: 60
    tokens: 16000
```

## Extension Playbook: Adding Agent Tools

1. Create the tool resource in Snowflake (semantic view, search service, or UDF)
2. Add the tool to the agent YAML spec in `deploy.sql` under `tools:` and `tool_resources:`
3. Recreate the agent: `CREATE OR REPLACE AGENT ...`
4. No frontend changes needed -- the agent handles tool routing

## Extension Playbook: Key Pair Setup

Run `tools/01_setup.sh` which:
1. Generates RSA 2048-bit key pair
2. Creates `deploy_with_key.sql` with the public key ALTER USER statement
3. Creates `.env` with account, user, key path, and agent config
4. Grants CORTEX_AGENT_USER role

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT` |
| Agent | `SFE_REACT_DEMO_AGENT` |
| Role | `CORTEX_AGENT_USER` (application role grant) |

## Gotchas

- CORTEX_AGENT_USER role grant requires ACCOUNTADMIN
- JWT `iss` field format: `ACCOUNT.USER.SHA256:fingerprint` (all uppercase)
- SSE responses contain `delta` events with incremental text -- accumulate for full response
- Thread IDs enable multi-turn conversation; omit for stateless queries
- The Express proxy is required -- direct browser-to-Snowflake calls hit CORS
- `tools/01_setup.sh` must run before first use (generates keys + .env)
- `concurrently` package runs React dev server + Express proxy simultaneously
