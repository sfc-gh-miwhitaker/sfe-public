# API Agent Context Guide

Working examples of calling the Snowflake `agent:run` API with execution context
(role and warehouse), including curl-based quick tests, Python client, and React integration.

## Project Structure
- `README.md` -- Quick Start and key concepts
- `agent_run_with_context.py` -- Python examples with PAT/OAuth auth and streaming
- `agent_run_react.md` -- React + Express integration guide

## Content Principles
- Practical examples first, theory second
- Three integration levels: curl, Python, React
- Both agent-object and inline-config API approaches
- PAT auth for quick testing, OAuth for production

## When Helping with This Project
- This is a guide, not a demo -- no deploy_all.sql, no expiration, no Snowflake objects
- The `agent:run` endpoint accepts `role` and `warehouse` in execution context
- PAT auth header format: `Authorization: Bearer <pat_token>`
- SSE streaming: parse `event: delta` lines for incremental response text
- Thread creation via `/api/v2/cortex/agent:create-thread` for multi-turn
- Python example uses `requests` with streaming response iterator
- React guide uses Express backend proxy to avoid CORS issues
