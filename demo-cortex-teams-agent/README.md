![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--04--01-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Cortex Agents for Microsoft Teams & M365 Copilot

> **DEMONSTRATION PROJECT - EXPIRES: 2026-05-01**
> This demo uses Snowflake features current as of March 2026.
> After expiration, a warning banner will be added to this README and deploy_all.sql.
> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

**Pair-programmed by:** SE Community + Cortex Code
**Last Updated:** 2026-03-02 | **Expires:** 2026-05-01 | **Status:** ACTIVE

---

**Chat with AI-powered agents directly in Microsoft Teams and M365 Copilot -- zero custom code required.**

---

## Quick Start

**Deploy in Snowsight (no clone needed):**
Copy [`deploy_all.sql`](deploy_all.sql) into a Snowsight worksheet and click **Run All**.

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) demo-cortex-teams-agent
cd sfe-public/demo-cortex-teams-agent && cortex
```

## First Time Here?

1. **Deploy** -- Copy `deploy_all.sql` into Snowsight, click "Run All"
2. **Configure Entra ID** -- Grant consent for both apps (docs/02-ENTRA-ID-SETUP.md)
3. **Set Tenant ID** -- Update `YOUR_TENANT_ID` in the security integration section
4. **Install Teams App** -- Search "Snowflake Cortex Agents" in Teams store
5. **Test** -- Ask for a joke!

**Total setup time: ~15 minutes**

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.cortex/skills/** -- Project-specific skills for Cortex Code CLI
- **Cortex Code in Snowsight** -- Open this project in a Workspace for AI-assisted development
- **Cursor** -- Open locally with Cursor for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)

---

## What This Creates

| Object Type | Name | Purpose |
|---|---|---|
| Schema | `SNOWFLAKE_EXAMPLE.TEAMS_AGENT` | Demo schema |
| Warehouse | `SFE_TEAMS_AGENT_WH` | Demo compute |
| Agent | `JOKE_AGENT` | Cortex Agent for Teams/M365 |
| Function | `TELL_JOKE` | AI_COMPLETE joke generator |
| Security Integration | OAuth with Microsoft Entra ID | Teams authentication |

## What You Get

**Zero Development:**
- No custom bot code to write or maintain
- No hosting infrastructure needed
- Install from AppSource in minutes
- `CREATE AGENT` DDL for one-command deployment

**Enterprise Security:**
- OAuth with Microsoft Entra ID (SSO, MFA)
- Snowflake RBAC automatically enforced
- Content safety via Cortex Guard
- Complete audit trail in QUERY_HISTORY

**AI-Powered:**
- Snowflake Cortex AI (`AI_COMPLETE` function)
- Cortex Guard filters unsafe content
- Natural language understanding
- Works in Teams AND Microsoft 365 Copilot

---

## Example Conversation

**You:** Tell me a joke about data engineers

**Bot:** Why do data engineers prefer dark mode? Because light attracts bugs, and they've already got enough of those in their pipelines!

**You:** Give me one about SQL

**Bot:** Why did the SQL query go to therapy? It had too many relationships but still felt empty!

---

## Project Structure

```
teams-agent-uni/
|-- AGENTS.md                              # AI-pair instructions
|-- README.md                              # You are here
|-- deploy_all.sql                         # One-click deployment (Run All)
|-- teardown_all.sql                       # Complete removal
|-- .cortex/skills/demo-guide/SKILL.md     # Project-specific AI skill
|-- diagrams/
|   |-- data-model.md                      # Object model
|   |-- data-flow.md                       # Data flow diagram
|   |-- auth-flow.md                       # Authentication sequence
|   `-- network-flow.md                    # Network architecture
|-- sql/
|   |-- 01_setup/
|   |   |-- 01_create_demo_objects.sql     # Database, schema, warehouse
|   |   |-- 02_create_joke_function.sql    # AI_COMPLETE joke generator
|   |   |-- 03_create_agent.sql            # CREATE AGENT DDL
|   |   |-- 04_create_security_integration.sql  # OAuth with Entra ID
|   |   `-- 05_grant_permissions.sql       # RBAC grants
|   `-- 99_cleanup/
|       `-- teardown_all.sql               # (See root teardown_all.sql)
|-- docs/
|   |-- 01-PREREQUISITES.md               # Requirements checklist
|   |-- 02-ENTRA-ID-SETUP.md              # Entra ID consent + security integration
|   |-- 03-INSTALL-TEAMS-APP.md           # Teams & M365 Copilot install
|   `-- 04-CUSTOMIZATION.md              # Production use cases & handoff
`-- .github/workflows/
    |-- expire-demo.yml                    # Auto-archive on expiration
    `-- pre-commit.yml                     # Pre-commit checks
```

---

## Beyond Jokes: Real Use Cases

This demo proves the architecture. The **same pattern** powers enterprise analytics:

| Use Case | Agent Tool | Example Question |
|---|---|---|
| Sales Analytics | Cortex Analyst + Semantic View | "What were Q4 revenues by region?" |
| Customer Support | Cortex Search + Knowledge Base | "How do I reset a customer password?" |
| Financial Reporting | Cortex Analyst + Semantic View | "Show budget vs actual for January" |
| Data Quality | Custom Tool (UDF) | "Any data quality issues today?" |

See `docs/04-CUSTOMIZATION.md` for production agent patterns.

---

## Security & Governance

### Authentication Flow

1. User opens Teams bot (or M365 Copilot)
2. Bot redirects to Microsoft Entra ID login
3. User authenticates (SSO, MFA, Conditional Access)
4. Entra ID issues short-lived JWT token
5. Token sent to Snowflake Cortex Agents API
6. Snowflake validates token and executes as user's role

### What's Protected

- **Snowflake data** never leaves Snowflake's environment
- **RBAC enforced** on all queries (users see only permitted data)
- **Row-level security** and **data masking** policies respected
- **Audit logs** in QUERY_HISTORY and CORTEX_AGENT_USAGE_HISTORY

---

## Estimated Demo Costs

### Snowflake

| Component | Estimate |
|---|---|
| Warehouse (XSMALL, 60s auto-suspend) | ~0.0001-0.0003 credits per joke |
| AI_COMPLETE tokens (~300 in + 100 out) | ~$0.0005 per joke |
| **1,000 jokes total** | **< $1.00** |

### Microsoft

- **Teams:** Included with Microsoft 365 license
- **AppSource app:** Free
- **Entra ID OAuth:** No additional charges
- **M365 Copilot:** Requires Copilot license (if using Copilot integration)

---

## Complete Cleanup

```sql
-- Run in Snowsight:
-- teardown_all.sql
```

Removes: Agent, function, schema, warehouse, grants.
Preserves: SNOWFLAKE_EXAMPLE database, security integration.

**Manual steps:**
- Uninstall Teams app
- (Optional) Revoke Entra ID consent in Azure Portal

---

## Reference

**Snowflake Documentation:**
- [Cortex Agents for Teams and M365 Copilot](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-teams-integration)
- [CREATE AGENT](https://docs.snowflake.com/en/sql-reference/sql/create-agent)
- [AI_COMPLETE](https://docs.snowflake.com/en/sql-reference/functions/ai_complete)
- [Build Agents (Snowflake Intelligence)](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence/build-agents)
- [Best Practices for Building Cortex Agents](https://www.snowflake.com/en/developers/guides/best-practices-to-building-cortex-agents/)

**Quickstart:**
- [Getting Started with Cortex Agents for Microsoft Teams and M365 Copilot](https://quickstarts.snowflake.com/guide/getting_started_with_the_microsoft_teams_and_365_copilot_cortex_app)

**Microsoft Documentation:**
- [Microsoft Teams App Management](https://learn.microsoft.com/microsoftteams/manage-apps)
- [Microsoft Entra ID](https://learn.microsoft.com/entra/)

---

## License

This demo project is provided as-is for educational purposes.

**Snowflake Terms:** [snowflake.com/legal](https://www.snowflake.com/legal/)
**Microsoft Terms:** [microsoft.com/servicesagreement](https://www.microsoft.com/servicesagreement/)
