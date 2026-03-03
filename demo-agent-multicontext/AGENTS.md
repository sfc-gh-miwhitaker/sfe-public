# Agent Multicontext Demo

Demonstrates per-request context injection using the Snowflake Agent Run API "without agent object" endpoint for a TV network use case.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered 01-06)
- `backend/` -- Node.js/Express proxy with context builder
- `frontend/` -- React app with chat UI and API inspector

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: AGENT_MULTICONTEXT
- Warehouse: SFE_AGENT_MULTICONTEXT_WH
- Semantic View: SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AGENT_MULTICONTEXT_VIEWERSHIP

## Key Concepts
- Uses `POST /api/v2/cortex/agent:run` (without agent object) for per-request instructions
- `instructions.system` carries user identity and station branding
- Tool selection varies by auth tier (anonymous vs low vs full)
- `X-Snowflake-Role` header sets Snowflake RBAC context per request

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
- All new objects need COMMENT = 'DEMO: ... (Expires: 2026-04-02)'

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql as the single entry point
- The backend context builder in `backend/server.js` is the authoritative source for payload construction
- The frontend `buildAgentPayload.ts` mirrors the backend logic for the API Inspector preview
