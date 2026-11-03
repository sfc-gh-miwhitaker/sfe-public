![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--01--02-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake CoWork: The Easter Egg Compendium

Snowflake CoWork (`ai.snowflake.com`, formerly Snowflake Intelligence) is a governed AI work agent that does much more than answer data questions. This guide maps the current capability surface, including generally available features and open previews, with emphasis on the moves that are easy to miss: depth modes, reusable workflows, live artifacts, chart controls, connected tools, memory, and cost guardrails. Object and SQL names such as the `SNOWFLAKE_INTELLIGENCE` database and `CREATE SNOWFLAKE INTELLIGENCE` keep the earlier name.

Think of this as a field guide for the person who already knows CoWork exists but hasn't found the backslide-kickflip yet.

**Audience:** SEs, SAs, and CoWork admins who want to demo the full capability surface and understand each feature's availability and prerequisites.

**Created:** 2026-08-04 | **Last verified:** 2026-11-03 | **Expires:** 2027-01-02 | **Status:** ACTIVE

Pair-programmed by SE Community + Cortex Code

> **No support provided.** Reference only; validate before production use.

---

## The One-Paragraph TL;DR

CoWork combines Cortex Agents with structured and unstructured data, most Vega-Lite chart types, Deep Research (including web research when web search is enabled), persistent artifacts, recurring email reports, reusable user skills, PDF, Word, PowerPoint, and HTML generation, external MCP tools, user memory, and a native iOS app. Most of these are GA; chart customization and User Skills remain open Preview and may change. The important distinction is no longer "available versus coming" but **what is available, at what stage, and under which controls**.

---

## Start Here

**Want to use CoWork right now?** Open [What Can I Do Now?](WHAT-CAN-I-DO-NOW.md) for an outcome-based menu, ready-to-run prompts, prerequisites, and first-line troubleshooting.

**Already know CoWork exists?** Start with [The `+` Menu](#1-the--menu-is-your-command-center) and [Deep Research](#2-deep-research----the-investigation-mode). Those two sections change most demos.

**About to show this to a customer?** Read [Common Misconceptions](#common-misconceptions-to-correct-in-demos) first. Availability, live artifacts, web search, artifact sharing, and MCP setup are the claims most likely to be overstated.

**Configuring an enterprise rollout?** Jump to [Admin Tricks](#admin-tricks), [MCP Connectors](#10-mcp-connectors----governed-connections-not-zero-setup), and [Cost Controls](#15-cost-controls----budgets-quotas-and-usage-history).

---

## Surface Map

| Capability | Availability | Where to find it |
| --- | --- | --- |
| Deep Research | GA | `+` menu -> Deep Research |
| Web research in Deep Research | Available when the agent's web search tool is enabled | Agent tools, after account-level enablement |
| Extended Thinking | GA | Chat controls |
| File upload | GA | `+` menu -> Upload file |
| Artifacts | GA | Artifacts hub |
| Shared conversations | GA | Conversation share menu |
| Chart customization | Preview | Agent or semantic-view instructions |
| User Skills | Preview | `+` menu -> Skills; Capabilities -> Skills |
| Automations | GA | Automations tab or conversation |
| Document generation | GA | Ask for PDF, Word, PowerPoint, or HTML in chat |
| Code execution tool (prerequisite for documents and scripted skills) | GA | Agent tools |
| MCP Connectors | Available; no separate stage published | Agent settings and Sources panel |
| CoCo Skill and Plugin Catalog | GA | `AI & ML` -> Skills and plugins; CoCo `+` or `/` menu |
| User memory | Available; no separate stage published | Settings -> Memories |
| Verified Answers | Available; no separate stage published | Responses grounded in verified queries |
| iOS app | GA | App Store: Snowflake CoWork |
| Teams and Microsoft 365 Copilot | Available; no separate stage published | Microsoft AppSource |
| Resource budgets | Available; no separate stage published | Budgets in Snowsight or SQL |
| Per-user quotas | GA | Per-user quota settings in Snowsight or SQL |

---

## What You Can Do Today

### 1. The `+` Menu Is Your Command Center

The `+` button beside the message bar opens capabilities that are otherwise easy to miss. Entries vary by account, agent configuration, and preview enrollment.

- **Deep Research** starts a multi-step investigation.
- **Upload file** adds local context to the thread.
- **Agent** selects a specialist explicitly.
- **Skills** runs or creates reusable user workflows when enabled.

The menu is a capability launcher, not proof that every feature is GA or enabled for every user.

---

### 2. Deep Research -- The Investigation Mode

Deep Research is GA. It decomposes a complex question into parallel sub-investigations across the agent's structured and unstructured sources, then produces a report whose claims trace back to source data and queries.

**How to trigger it:** `+` menu -> Deep Research. An investigation can take up to 10 minutes.

- Follow-up questions use the completed report as thread context and do not restart the full investigation.
- Extended Thinking can be enabled at the same time for deeper reasoning within the broader investigation.
- Use standard chat for quick metrics and specific lookups; use Deep Research for open-ended "why" questions.
- Deep Research does not make an unconfigured source available. When the agent has web search enabled, Deep Research also researches the web and cites web sources in the report; that web research runs separately and has no access to your data. Without web search, investigations use only your data.
- Web search is an agent tool. An account administrator must enable web search at the account level before it can be added to an agent.

---

### 3. Extended Thinking -- The Deliberate Lane

Extended Thinking asks the agent to spend more reasoning effort on a response. It can improve complex analysis, but it can also increase latency and token use.

**The easy-to-miss behavior:** The setting remains selected for later messages. Turn it off when returning to quick lookups.

---

### 4. File Upload -- Thread-Scoped Working Context

CoWork can analyze uploaded documents, spreadsheets, presentations, code/data files, and images alongside governed Snowflake data.

**Supported types:** `.pdf`, `.txt`, `.md`, `.doc`, `.docx`, `.xls`, `.xlsx`, `.csv`, `.pptx`, `.json`, and common image formats including PNG, JPEG, GIF, SVG, BMP, TIFF, WebP, and HEIC/HEIF. Each file must be under 50 MB; a user can upload up to five files.

- Files are stored on the user's personal stage and are available in the same thread.
- They are removed when the thread is deleted or its retention period expires.
- Complex processing can use Snowpark on the user's default warehouse.
- Uploaded content is customer data and follows Snowflake governance. Administrators retain access according to existing privileges.

---

### 5. Artifacts -- Live References, Not Screenshots

A saved chart or table artifact preserves its SQL query, visualization specification, and a viewer-specific cached snapshot. It can be revisited, refreshed, and shared without recreating the original prompt.

- The underlying query runs with the viewer's current credentials and respects RBAC, row access policies, and masking policies.
- An artifact auto-refreshes when viewed more than 12 hours after the viewer's last view; it can also be refreshed manually.
- Sharing sends a link, but a link is not an access grant. Recipients need access to the artifact itself and, to run its query, access to the source data.
- Which roles may share is controlled per artifact type with account-level privileges such as `MANAGE ACCESS ON CHART ARTIFACTS` and `MANAGE ACCESS ON THREAD ARTIFACTS`, granted to `PUBLIC` by default.
- The current artifact unit is one chart or table. Multi-tile collections, folders, and labels are not supported.
- The manual chart editor supports bar, line, pie, and scatter charts. For other chart types, ask CoWork to change the chart.
- An ACCOUNTADMIN can turn off **Sharing artifacts and chats** account-wide under Data controls in the CoWork settings in Snowsight. When off, new sharing is blocked and non-owners lose access to shared artifacts, even with existing grants. Turning the setting off is not a substitute for revoking grants.

---

### 6. Shared Conversations -- Static, Shareable Context

Shared conversations are GA and are stored as Thread artifacts, but they are not live. A shared conversation is a snapshot of the thread, including its text and visualizations, at sharing time.

- The snapshot does not rerun queries or refresh.
- A recipient sees the saved content even without access to the original source data, so review the thread for sensitive content before sharing.
- Its lifecycle is tied to the source conversation. Deleting the source conversation, explicitly or through retention, deletes the shared snapshot and conversations started from it.
- Revoking access to a shared conversation makes conversations started from that snapshot inaccessible.

---

### 7. Chart Customization -- Three Levels of Control (Preview)

CoWork supports most Vega-Lite chart types, including area, heatmap, box plot, layered and dual-axis, faceted, error-bar, and text-annotation charts. Geographic map charts are not supported.

**Tier 1: Free-text guidance.** Add preferences inside a `<chart_customization>` block in agent orchestration instructions or semantic-view SQL-generation instructions. This is best-effort behavior.

**Tier 2: `vega_template`.** Supply a partial Vega-Lite specification that is deterministically merged into every chart at that scope. Agent-level templates apply first; semantic-view templates apply second and win on conflicts. Use narrow semantic-view scope for field-specific rules.

**Tier 3: `viz_policies`.** Define conditional, deterministic rules for color, point shape, number format, sort order, and axis range. Policies run after chart generation and add no LLM latency.

> Templates and policies can silently misbehave when generated SQL aliases fields or when multiple color actions collide. Test representative merged specifications before rollout.

---

### 8. User Skills -- Reusable Personal Workflows (Preview)

User Skills capture a repeatable workflow once and run it again explicitly with `/skill-name`, from the Skills menus, or implicitly when the request strongly matches the skill description.

- Create a skill conversationally, through `+` -> Skills -> Create new, or by uploading a skill folder under Capabilities -> Skills.
- Chat-based creation and scripted or file-producing skills require the agent's code execution tool.
- Uploaded non-scripted skills can run without code execution.
- Skills use only tools already configured on the agent and run with the user's role and warehouse.
- User Skills are private to their creator and are distinct from developer-authored agent skills and the CoCo Skill Catalog.

---

### 9. Automations -- Fresh Reports by Email

Automations are GA. An automation re-runs a question against current data on an hourly, daily, weekly, or monthly schedule. Create it conversationally or from the Automations tab, and list, reschedule, pause, resume, or delete it the same ways.

- Delivery is email-only and requires a verified email address. An administrator can verify an email domain with a DNS TXT record to give every user in that domain verified status.
- Each run creates a conversation thread that can be opened for follow-up questions. Previous runs are viewable for up to 60 days.
- A forwarded email link does not open the report for the recipient. Use Share to send a snapshot instead.
- The minimum frequency is once per hour.
- Automations run with caller rights on the user's own role and warehouse, billed as standard Snowflake task usage.
- Admins control access with the `EXECUTE AGENT TASK` account privilege, granted to `PUBLIC` by default. To restrict it, revoke from `PUBLIC` and grant to selected roles:

```sql
REVOKE EXECUTE AGENT TASK ON ACCOUNT FROM ROLE PUBLIC;
GRANT EXECUTE AGENT TASK ON ACCOUNT TO ROLE <role_name>;
```

---

### 10. MCP Connectors -- Governed Connections, Not Zero Setup

External MCP connectors let Cortex Agents and CoWork discover and invoke tools in systems such as Atlassian, GitHub, Glean, Linear, Salesforce, Google Workspace, and custom MCP-compatible services.

The setup has two layers:

1. An administrator creates an API integration and External MCP Server object, grants least-privilege access, and attaches the server to an agent.
2. Each user authorizes their own account with OAuth from the CoWork Sources panel.

Snowflake documents streamlined setup patterns for Atlassian, GitHub, Glean, Linear, and Salesforce. Google Workspace uses separate Snowflake-hosted MCP endpoints for Gmail, Drive, Calendar, and Contacts. External MCP servers are third-party systems: verify their tools and descriptions before granting access.

> Web search is separate from MCP connector setup. A connector does not implicitly grant internet search.

For custom connectors that use `TYPE = OAUTH2`, set `OAUTH_REFRESH_TOKEN_VALIDITY` (at least 3600 seconds). The default of 0 is treated as a refresh token that never expires. Disabling the API integration immediately invalidates all user tokens for that connector.

---

### 11. Document Generation -- PDF, Word, PowerPoint, and HTML

Document generation is GA, including HTML output. CoWork can package a conversation's analysis as a PDF (`.pdf`), Word (`.docx`), PowerPoint (`.pptx`), or HTML (`.html`) file and display it inline. The associated agent must have the Cortex Agent code execution tool, which is GA, enabled. New agents created in Snowsight have the Code Execution toggle on by default.

- Ask for the format directly in chat and describe the audience and content.
- Upload a PowerPoint template to guide deck styling. A PDF can be uploaded as a reference, but the output is not guaranteed to follow its layout.
- User and agent skills can define a repeatable structure or template workflow, and they take precedence over the built-in behavior.
- Google Doc generation is not part of the documented output formats.

---

### 12. Verified Answers -- The Trust Signal

Verified Answers let data teams add trusted responses. Verified queries in a semantic view give CoWork a reviewed path for common or complex questions: when a question is highly similar to a verified query, CoWork uses a verified-query fast path with lower latency, and when it exactly matches, CoWork runs that query's validated SQL directly instead of generating new SQL.

- Start with high-value KPI questions whose definitions must remain consistent.
- Treat verified queries as regression assets, not a substitute for a well-modeled semantic view.
- Users can inspect the sources and generated query behind an answer.

---

### 13. CoCo Skill and Plugin Catalog -- A Separate Catalog

Skill and plugin sharing is GA. CoCo skills and plugins are published as Cortex Extension objects and shared within a Snowflake account through a `snow://skill_catalog/...` URI.

- Access and catalog discoverability are independent controls.
- Every shared skill and plugin is security-scanned. A failed or pending scan blocks others from installing it; an administrator can override a false positive.
- Certification is tied to a specific version; an unversioned URI resolves to the newest certified version with an eligible scan status.
- Admins can manage categories, ownership, access, visibility, and 28-day install and usage telemetry, and can delegate these actions to non-ACCOUNTADMIN roles.
- CoWork has no catalog browse surface. A shared skill reaches CoWork users only when the agent's configuration references its Cortex Extension, and the user needs `READ` on that extension.
- This catalog is not the same product as CoWork User Skills.

---

### 14. Mobile and Microsoft Surfaces

The iOS app is GA and supports chat, agents, file and image attachments, voice input, citations, and role and warehouse selection. Do not assume every browser-only administration flow is available on mobile.

The Cortex Agents integration for Microsoft Teams and Microsoft 365 Copilot reuses the same agents as CoWork. It requires Microsoft and Snowflake administrator setup, Entra ID authentication, individual Snowflake users, and appropriate default-role access. Private Link is not supported for this integration, and accounts outside Azure US East 2 require consent for prompt and response processing there.

---

### 15. Cost Controls -- Budgets, Quotas, and Usage History

CoWork cost controls operate in credits, not raw token-count ceilings.

- **Resource budgets** track monthly credit consumption for a CoWork object and can call stored procedures at thresholds, such as revoking access at 100 percent.
- **Shared resource budgets** apply independent limits to tagged groups of users sharing the same CoWork object.
- **Per-user quotas** (GA) provide daily, weekly, or monthly user-level credit limits on UTC cycles, with optional blocking across AI functions, Cortex Agents, CoWork, CoCo, and the AI Gateway. Warehouse spend can be tracked in a quota but is not blocked. Users can check the quotas that apply to them with the `SNOWFLAKE.LOCAL.MY_BUDGET_SUMMARY()` table function (GA).
- Budget enforcement is not instantaneous: standard enforcement can lag by up to eight hours; low-latency budgets can reduce that to about two hours.
- Request-level telemetry is available in `SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COWORK_USAGE_HISTORY`; that view can lag up to one hour, while SQL cost-attribution fields can lag up to eight hours. The organization equivalent in `SNOWFLAKE.ORGANIZATION_USAGE` can lag up to 24 hours, with SQL cost-attribution fields lagging up to 32 hours.

---

### 16. User Memory -- Preferences That Persist

User memory lets CoWork remember preferences a user asks it to save, such as "Remember that I prefer concise answers," and apply them in later conversations.

- Memory applies only to CoWork interactions, not to direct calls through the Cortex Agent API.
- To stop using saved memories, open Settings -> Memories and turn off **Reference saved memories**. This applies only to that user and does not delete existing memories.

---

## Admin Tricks

### Customize the CoWork Experience

Under `AI & ML` -> Agents -> Open settings, admins can configure the display name, welcome message, primary color, and full-length and compact logos (the compact logo is also the browser-tab icon). Use these controls instead of relying on an object's internal name as user-facing branding.

### Seed Useful Starting Questions

Use agent sample questions and clear tool descriptions to direct users toward reliable, high-value workflows. Keep each agent narrow enough that tool selection remains predictable.

### Prefer Current Agent Visibility Management

Use the account-level Snowflake CoWork object to curate visible agents. Managing visibility through the `SNOWFLAKE_INTELLIGENCE.AGENTS` schema is deprecated. Once the object exists, an agent must be added to it to appear in CoWork:

```sql
SHOW SNOWFLAKE INTELLIGENCES;
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT ADD AGENT <db.schema.agent_name>;
```

### Restrict Users to CoWork Only

`ALTER USER <user_name> SET ALLOWED_INTERFACES = (SNOWFLAKE_INTELLIGENCE);` limits a user to the CoWork interface. SCIM provisioning can set the same restriction with the `allowedInterfaces` attribute.

---

## Common Misconceptions to Correct in Demos

| Misconception | Reality |
| --- | --- |
| "Everything in the `+` menu is GA" | The menu mixes GA and Preview capabilities; availability also depends on account and agent configuration. |
| "Deep Research automatically searches the web" | It researches the web only when the agent has web search enabled; otherwise it uses only your data. |
| "Anyone with an artifact link can open it" | A link is not an access grant. Recipients need artifact access, and source-data access to refresh. |
| "Artifacts refresh every time they're opened" | Live chart/table artifacts auto-refresh after more than 12 hours since the viewer's last view, or on manual refresh. |
| "Shared conversations are live dashboards" | Shared conversations are static snapshots. Chart/table artifacts are live references. |
| "Charts are limited to bar, line, and pie" | CoWork supports most Vega-Lite chart types; geographic maps are the notable exception. |
| "MCP connectors require no admin setup" | Admins configure API integrations, MCP server objects, grants, and agent attachment; each user then completes OAuth. |
| "Automations can deliver to Slack" | Automations deliver by email only. |
| "Budgets stop spend immediately" | Budget evaluation is periodic and enforcement can lag by hours. |
| "Deep Research web research needs only the agent toggle" | Web search must first be enabled at the account level, then added to the agent. |
| "Skill Catalog and User Skills are the same" | User Skills are personal CoWork workflows; the Cortex Extension catalog distributes CoCo skills and plugins within an account and reaches CoWork only through agent configuration. |

---

## Related Guides

- [Snowflake CoWork documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork) -- official feature reference
- [Cortex Agents overview](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents) -- the agent API that powers CoWork
- [Semantic views overview](https://docs.snowflake.com/en/user-guide/views-semantic/overview) -- the governed data layer used by Cortex Analyst
- [MCP Connectors](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp-connectors) -- external tool setup and security

---

## External References

- [Snowflake CoWork overview](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork)
- [Chart and Thread artifacts in Snowflake CoWork](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/artifacts)
- [Snowflake Artifacts](https://docs.snowflake.com/en/user-guide/snowflake-artifacts)
- [User access and settings for agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/deploy-agents)
- [Automations in Snowflake CoWork](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/automations)
- [User Skills in Snowflake CoWork](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/user-skills)
- [Document generation in Snowflake CoWork](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/document-generation)
- [Chart customization](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/chart-customization)
- [Visualization policies](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-viz-policies)
- [Cortex Agent code execution tool](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-code-execution-tool)
- [Create and manage agents (web search tool)](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage)
- [Cortex Agents for Microsoft Teams and Microsoft 365 Copilot](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-teams-integration)
- [Resource budgets for Snowflake CoWork](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/cowork-resource-budgets)
- [Per-user quotas](https://docs.snowflake.com/en/user-guide/budgets/per-user-quotas)
- [SNOWFLAKE_COWORK_USAGE_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/snowflake_cowork_usage_history_view)
- [Share skills and plugins](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-skill-plugin-sharing)
- [Snowflake CoWork on the App Store](https://apps.apple.com/us/app/snowflake-intelligence/id6755540372)
