# MCP Server Authentication Guide

Visual walkthrough of how authentication works with Snowflake's managed MCP server: PAT quick-start, OAuth + PKCE production flows, RBAC role-scoping, multi-tenant patterns, and known limitations with honest workarounds.

## Project Structure

- `README.md` -- Complete guide (6 parts + production checklist)
- `diagrams/` -- Mermaid diagrams for auth flows and decision frameworks

## Content Principles

- Scenario-driven: each part opens with a persona and real-world use case
- Honest about product gaps (external IdP tokens, per-tool OAuth scopes, streaming)
- SQL and config examples are concrete and copy-pasteable
- Mermaid diagrams in every part for visual learners
- Cross-links to sibling projects for deeper dives

## When Helping with This Project

- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects to create
- All SQL and config snippets are embedded in README.md
- Two auth methods exist today: PAT (dev/testing) and OAuth 2.0 (production)
- External IdP OAuth tokens for MCP are a product gap -- do not claim they work natively
- Access to MCP server does NOT grant access to tools -- both must be granted separately
- Hostname constraint: use hyphens not underscores in MCP server URLs
- DDL via sql_exec_tool is unreliable -- the managed MCP server is read-mostly by design
- No streaming responses yet -- full responses only
- No per-tool OAuth scopes -- scoping is per-server via Snowflake RBAC

## Related Projects

- [`guide-agent-governance`](../guide-agent-governance/) -- Agent governance playbook (RBAC, monitoring, cost)
- [`guide-agent-multi-tenant`](../guide-agent-multi-tenant/) -- Multi-tenant agent pattern with OAuth + RAPs
- [`guide-api-agent-context`](../guide-api-agent-context/) -- Agent Run API with three auth methods
- [`guide-external-access-playbook`](../guide-external-access-playbook/) -- External access patterns and secrets
- [`tool-secrets-rotation-aws`](../tool-secrets-rotation-aws/) -- PAT and key-pair rotation automation
- [`tool-cortex-cost-intelligence`](../tool-cortex-cost-intelligence/) -- MCP integration docs
