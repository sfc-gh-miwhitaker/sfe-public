# Multi-Tenant Cortex Agent — Project Instructions

## Architecture

Documentation-only reference guide (no deploy scripts, no Snowflake objects to create).

Single-file guide focused on need-to-knows and gotchas for API-driven multi-tenant agent applications. The gotchas table (Part 3) is the centerpiece.

## Conventions

- Placeholder syntax: `<UPPERCASE_WITH_UNDERSCORES>` for values the reader must replace
- Shell variables: `${ACCOUNT}`, `${DB}`, `${SCHEMA}`, `${AGENT}`, `${TOKEN}`
- SQL uses `ACCOUNTADMIN` for RAP creation, a dedicated `agent_service_role` for runtime
- Pattern A (session variables) is the recommended default for API-driven use cases
- All curl examples use the "with agent object" endpoint unless noted

## Key Patterns

```bash
# Pattern A: Session variables (recommended)
curl -X POST "https://${ACCOUNT}.snowflakecomputing.com/api/v2/databases/${DB}/schemas/${SCHEMA}/agents/${AGENT}:run" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{"messages":[...],"variables":{"tenant_id":{"value":"X","type":"string","is_immutable_session_attribute":true}}}'

# SQL: RAP referencing session variable
SYS_CONTEXT('SNOWFLAKE$SESSION_ATTRIBUTES', 'tenant_id')

# SQL: Per-tenant monitoring
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY;
```

## Critical Gotchas to Maintain

These are the validated findings that make this guide valuable. Do not remove without re-verification:

1. DEFAULT_ROLE cannot be overridden via API
2. Code execution tool uses OWNER's privileges
3. SYS_CONTEXT returns NULL if variable not set
4. Mapping table must be in same database for RAP
5. Sample values NOT masked in semantic views
6. Budget enforcement latency up to 8 hours
7. Thread state persists (tenant isolation risk)
8. 15-minute timeout per request
9. Rate limit headers NOT returned

## When Helping with This Project

- This is a reference guide — no deploy_all.sql, no app scaffold
- All SQL/curl/Python snippets are embedded in README.md
- Session variables pattern is the default recommendation
- Don't claim code_execution tool is safe for multi-tenant — it uses OWNER's role
- Don't claim budget enforcement is real-time — latency is 2-8 hours

## Related Projects

- [`guide-agent-hardening`](../guide-agent-hardening/) — Full governance playbook (6 pillars)
- [`guide-mcp-auth`](../guide-mcp-auth/) — MCP auth for all AI clients + multi-tenant in Part 4
- [`guide-connecting-claude-snowflake`](../guide-connecting-claude-snowflake/) — Claude-specific auth paths
- [`guide-external-access-playbook`](../guide-external-access-playbook/) — Network rules, secrets, OAuth
