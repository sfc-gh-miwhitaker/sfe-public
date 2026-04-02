# Multi-Tenant Cortex Agent with Azure AD

Guide for building a multi-tenant customer-facing application using the Snowflake Agent
Run API with Azure AD OAuth and Row Access Policies for per-customer data isolation.

## Project Structure
- `agent_run_multitenant.md` -- Complete implementation guide (~2000 lines)
- `diagrams.md` -- 12 Mermaid architecture diagrams

## Content Principles
- Reference architecture, not a deployable demo (no SQL scripts or deploy files)
- React + Node.js + Azure AD + Snowflake Agent API stack
- Production-grade patterns: rate limiting, audit logging, error handling
- Row Access Policies enforce tenant isolation via JWT claims

## When Helping with This Project
- This is a guide, not a demo -- no deploy_all.sql, no expiration, no Snowflake objects
- Architecture: React → Azure AD (OAuth) → Node.js backend → Snowflake (RAP enforced)
- Customer isolation uses JWT `customer_id` claim mapped to Row Access Policy
- Two authentication paths: Azure AD OAuth for customers, PAT for internal testing
- Agent calls use the "without agent object" inline-config approach
- Diagrams use Mermaid syntax -- follow conventions in diagrams.md
- The guide covers both happy path and error handling patterns
- For key-pair JWT auth as an alternative to Azure AD OAuth or PAT, see [`guide-api-agent-context/migrate_pat_to_keypair_jwt.md`](../guide-api-agent-context/migrate_pat_to_keypair_jwt.md)

## Related Projects
- [`guide-api-agent-context`](../guide-api-agent-context/) -- API code snippets (PAT, OAuth, Key-Pair JWT) and migration recipes
- [`demo-agent-multicontext`](../demo-agent-multicontext/) -- runnable demo with per-request context injection
- [`demo-cortex-teams-agent`](../demo-cortex-teams-agent/) -- Teams / M365 Copilot integration
