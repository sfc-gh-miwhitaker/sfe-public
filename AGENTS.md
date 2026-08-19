# sfe-public — Repository Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Do not duplicate them here. -->

This repository contains Snowflake SE community guides and demos. It is designed to be
maintained collaboratively with AI coding assistants (Cortex Code, Claude Code, Cursor).

---

## Repository Layout

```
sfe-public/
  guide-<name>/        Reference guides — no deploy script required
  demo-<name>/         Runnable demos — single deploy_all.sql entry point
  shared/              Shared setup scripts and pre-commit config templates
  _archive/            Retired projects (do not link to these)
```

## Attribution

Every file must carry:

```
Pair-programmed by SE Community + Cortex Code
```

No customer names, meeting references, or account identifiers in any committed file.
No personal names in the attribution line.

---

## Path Taxonomy — Maintain This When Adding or Removing Guides

The root `README.md` has a `## Start Here` section with a five-row intent routing
table. Every guide and demo belongs to one or more of these paths. When you add or
remove a project, update the routing table accordingly.

### Path 1 — Connect an External Tool to Snowflake

Guides that configure a third-party tool (BI, AI coding assistant, SIEM, etc.) to
authenticate and communicate with Snowflake.

**Current members:**
- `guide-coco-setup` — Cortex Code Desktop + CLI onboarding, configuration hierarchy, first skill
- `guide-powerbi-oauth` — Power BI OAuth SSO and DirectQuery
- `guide-connecting-claude-snowflake` — Claude Desktop and CoWork/CoCo surfaces
- `guide-claude-code-cortex-redirect` — Claude Code CLI and Anthropic/OpenAI SDK redirect
- `guide-vscode-copilot-cortex` — VS Code + GitHub Copilot
- `guide-snowflake-splunk-ingestion` — Splunk audit log ingestion (4 patterns)
- `guide-connecting-copilot-studio-snowflake` — Microsoft Copilot Studio (4 patterns: Knowledge Source, Cortex Analyst, MCP + Cortex Agent, REST API)

**Belongs here if:** the guide's primary job is configuring a named external product
to connect to Snowflake. Authentication setup, endpoint configuration, and integration
troubleshooting are the signals.

### Path 2 — Build a Production Cortex Agent

Guides covering the design, configuration, deployment, and extension of Cortex Agents.
Reading order within this path matters.

**Current members (in recommended reading order):**
1. `guide-model-agnostic-accuracy` — semantic view and agent configuration foundations
2. `guide-cortex-agent-versioning` — deployment lifecycle (LIVE → VERSION → alias)
3. `guide-agent-to-agent-orchestration` — multi-agent patterns (DATA_AGENT_RUN, MCP)
4. `guide-cortex-agent-image-tool` — custom generic tool pattern (optional, specialized)
5. `guide-cortex-search-access-control` — RBAC for Cortex Search (add when agent uses search)
6. `guide-connecting-copilot-studio-snowflake` — exposing a Cortex Agent via MCP to Microsoft Copilot Studio
7. `guide-cowork-only-users` — admin provisioning for CoWork-only user cohorts (RBAC, interface lock, SCIM)

**Belongs here if:** the guide's primary job is building, configuring, deploying, or
extending a Cortex Agent or its supporting objects (semantic views, tools, search).

### Path 3 — Govern Snowflake Costs and Usage

Guides covering credit visibility, AI service governance, warehouse controls, and
compute rightsizing. Reading order within this path matters.

**Current members (in recommended reading order):**
1. `guide-snowflake-cost-visibility` — foundational: Budget objects, METERING_DAILY_HISTORY,
   Resource Monitors, AI_FUNCTIONS_USER RBAC
2. `demo-cortex-ai-cost-controls` — AI enforcement: usage view queries, runaway detection,
   per-user limits
3. `guide-adaptive-compute` — compute rightsizing: Adaptive warehouse parameters and tuning
4. `guide-org-reporting` — multi-account visibility: ORGANIZATION_USAGE two-path decision,
   application/database roles, query discipline, materialization pattern

**Belongs here if:** the guide's primary job is monitoring, alerting on, or limiting
Snowflake credit or AI token consumption.

### Path 4 — Secure Snowflake and Build an Audit Trail

Guides covering access control patterns, identity federation, and audit log export.
Each guide in this path is standalone — no required reading order.

**Current members:**
- `guide-cortex-search-access-control` — Cortex Search RBAC (also in Path 2)
- `guide-powerbi-oauth` — OAuth identity federation (also in Path 1)
- `guide-snowflake-splunk-ingestion` — Splunk SIEM ingestion (also in Path 1)
- `guide-cowork-only-users` — CoWork-only interface restriction via ALLOWED_INTERFACES (also in Path 2)
- `guide-snowflake-firewall-allowlist` — Edge firewall allowlisting (FQDN outbound + stable egress CIDR inbound)
- `guide-cortex-code-access-control` — Restrict CoCo to specific roles, progressive rollout, usage observability queries

**Belongs here if:** the guide's primary job is enforcing access boundaries, establishing
identity federation, or feeding an audit or SIEM system.

### Path 5 — Understand New Snowflake Capabilities

Guides that explain and position recent Snowflake announcements. No required reading
order — pick based on area of interest.

**Current members:**
- `guide-coco-setup` — Cortex Code Desktop + CLI onboarding (also in Path 1)
- `guide-horizon-context-catalog` — Cortex Sense, Horizon Context, catalog pivot (Summit 2026)
- `guide-universal-data-sharing` — Open Data Sharing, OTF sharing, Collaboration API (Summit 2026)
- `guide-cowork-easter-eggs` — full CoWork feature surface: power-user tricks, chart customization, Uber Agent, Deep Research, Skills, Memory, Artifacts
- `guide-org-reporting` — ORGANIZATION_USAGE primer: two access paths, premium vs non-premium, query discipline

**Belongs here if:** the guide's primary job is explaining a new Snowflake feature or
capability rather than configuring or building something.

---

## Maintenance Rules

### When you add a new guide or demo

1. Determine which path(s) above it belongs to. A guide can appear in multiple paths
   if it genuinely serves multiple reader intents (e.g., `guide-cortex-search-access-control`
   belongs in both Path 2 and Path 4).
2. Add it to the **Current members** list in the relevant path section(s) above.
3. Add it to the `## Start Here` routing table in `README.md` in the appropriate row(s),
   with a linked guide name and brief description of where it fits in the reading order.
4. Add it to the `## Projects` table in `README.md` with the standard row format:
   `| [guide-name](guide-name/) | Description with key features and gotchas | Comma-separated feature tags |`
5. Update the `![Projects](...)` badge count in `README.md`.

### When you remove or archive a guide

1. Move the directory to `_archive/` (do not delete).
2. Remove it from the **Current members** list in AGENTS.md.
3. Remove it from the `## Start Here` routing table and `## Projects` table in `README.md`.
4. Search for `guide-<name>` across all other guide READMEs and remove or redirect
   any `Related Guides` or `Before You Start` cross-references that pointed to it.
5. Update the `![Projects](...)` badge count.

### When a guide's expiry date passes

1. Re-verify the content against current Snowflake documentation.
2. Update any facts, SQL syntax, availability statuses, or UI flows that have changed.
3. Move the expiry date forward by 3–6 months depending on the feature's rate of change.
4. Update the `![Expires](...)` badge in the guide's README.

---

## Guide Format Standards

Each guide README must include:

- Badge line: `![Guide]` `![No Deploy]` `![Expires]` `![Status]`
- H1 title
- One-paragraph description + audience line
- `Pair-programmed by SE Community + Cortex Code`
- `**Created:** YYYY-MM-DD | **Expires:** YYYY-MM-DD | **Status:** ACTIVE`
- `> **No support provided.** Reference only; validate before production use.`
- `---` divider before body content
- `## Start Here` or `## Quick Start` section near the top
- `## Related Guides` section near the bottom — **public, stable external links only** (docs.snowflake.com, etc.). Do NOT link to sibling guides in this repo — they expire and rot. Use the [Start Here index](README.md#start-here) for cross-guide navigation instead.
- `## External References` section at the end

Expiry dates: set 3–6 months from creation date. Guides covering private preview
features use 3 months; GA features use 6 months; connector/auth guides use 6 months.

---

## Pre-commit Hooks

This repo uses `detect-secrets` and a custom account-name scanner. Common issues:

- **Account name false positives:** use `<org>-<account>` with angle brackets in prose
  (prevents the regex match on `[a-z]{2,8}-[a-z0-9]{5,10}\.snowflake`).
- **Secret false positives:** add `# pragma: allowlist secret` inline comment.
- **`api_key` false positives:** use `api_key="placeholder"` with the allowlist comment.  # pragma: allowlist secret
