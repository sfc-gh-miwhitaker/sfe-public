# Cortex Agent Chat - React Integration

React.js chat interface for Snowflake Cortex Agents using REST API with key-pair JWT authentication.

## Project Structure
- `deploy.sql` -- Snowflake agent creation (Run All in Snowsight)
- `teardown.sql` -- Complete cleanup
- `server/` -- Express backend proxy (JWT signing)
- `src/` -- React frontend
- `tools/` -- Setup scripts (key generation, env files)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: SFE_CORTEX_AGENT_CHAT
- Agent: SFE_REACT_DEMO_AGENT

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Agent spec: Use `orchestration: auto`, always set budget (seconds + tokens)
- Security: Private key stays server-side only

## When Helping with This Project
- `CREATE AGENT` and `DESC AGENT` are correct syntax (no CORTEX keyword)
- Agent spec `models.orchestration` should be `auto` for portability
- Always include `orchestration.budget` with seconds and tokens limits
- CORTEX_AGENT_USER database role required for agent creation
- All new objects need COMMENT = 'TOOL: ... (Expires: YYYY-MM-DD)'
