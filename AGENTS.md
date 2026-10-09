# sfe-public — Repository Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Do not duplicate them here. -->

This repository contains Snowflake SE community guides and demos. It is designed to be
maintained collaboratively with AI coding assistants (Cortex Code, Claude Code, Cursor).

---

## Repository Layout

```text
sfe-public/
  guide-<name>/        Reference guides — no deploy script required
  demo-<name>/         Runnable demos — single deploy_all.sql entry point
  shared/              Shared setup scripts and pre-commit config templates
  _archive/            Retired projects (do not link to these)
```

## Attribution

Every file must carry:

```text
Pair-programmed by SE Community + Cortex Code
```

No customer names, meeting references, or account identifiers in any committed file.
No personal names in the attribution line.

---

## Path Taxonomy — Maintain This When Adding or Removing Guides

The root `README.md` has a `## Start Here` section with a six-row intent routing
table. Every guide and demo belongs to one or more of these paths. When you add or
remove a project, update the routing table accordingly.

### Path 1 — Connect an External Tool to Snowflake

Guides that configure a third-party tool (BI, AI coding assistant, SIEM, etc.) to
authenticate and communicate with Snowflake.

**Current members:**

- `guide-claude-code-coco` — Claude Code delegation: AI Kit first, native CoCo MCP alternative, bounded context, permissions, sessions, and evidence-based completion; VS Code users default to the official Snowflake extension
- `guide-codex-coco` — Codex delegation: native CoCo MCP first, AI Kit alternative with Codex-specific approval and child-MCP limitations, bounded context and evidence; VS Code users default to the official Snowflake extension
- `guide-claude-desktop-coco` — Claude Desktop chat delegation through local CoCo MCP: print-only configuration helper, absolute executable paths, independent child calls, approval boundaries, and official VS Code extension routing
- `guide-snowflake-mcp-role-controls` — Snowflake-managed MCP primary-role OAuth controls and secondary-role session-policy restrictions
- `guide-salesforce-v2-zero-copy` — Salesforce and Snowflake bidirectional zero copy: V2 Data Share, query/file federation, legacy V1/BYOL, Openflow and MCP boundaries
- `guide-cube-snowflake-semantic-layer` — Cube (cube.dev) semantic layer: driver config, three auth paths, OIDC workload identity, pre-aggregation cost
- `guide-debezium-to-snowflake` — Debezium CDC pipeline: Debezium + Kafka + Snowflake Kafka Connector v4 + Dynamic Table flattening (all GA)
- `guide-delta-sharing-ip-allowlist` — Databricks Delta Sharing feeds whose provider restricts access to allowlisted IPs and asks for one to three addresses. Answer-first: run the Delta Sharing client in your own cloud account behind a NAT gateway with a static IP and land via external stage, because it is the only design needing nothing new from the provider. Then the four provider questions (accept a shared CIDR, OIDC federation, OAuth2 client credentials, waive the allowlist for a federated recipient) that collapse it to the native `CATALOG_SOURCE = DELTA_SHARING` integration's two statements, the protocol-version-1 credential-vending failure and its external-volume fallback, why outbound private connectivity is documented for Iceberg REST but not Delta Sharing, Data Connectivity Proxy as the answer to the inverse problem, the SPCS client as the inside-Snowflake alternative if they accept a shared `/24`, the shared-`/24` and expiry realities, and the two-allowlist-entry onboarding trap
- `guide-ad-platform-integrations` — Advertising data by direction: Google Ads Data Manager outbound (Snowflake as native first-party source, PAT auth, Customer Match), the Meta ads MCP + Conversions API skill pairing (CAPI skill public on GitHub, MCP by request), and the Openflow connectors for Meta Ads and Google Ads inbound (Preview connectors on a GA platform)
- `guide-shopify-multistore-snowflake` — Shopify (dozens of stores) into Snowflake by either of two paths: the Preview Openflow Shopify connector on a GA Openflow Snowflake Deployment, or a deterministic native Bulk API pipeline (Python procedure + Task + SECRET/EAI) operated through CoCo. Shared store registry, one reconciled `DAILY_SHOP_ACTIVITY` analytics contract published under a single view name so a path switch touches no report, honest readiness and cost-floor section, ELT cutover pattern
- `guide-otel-to-snowflake` — External OpenTelemetry logs, metrics, and traces into Snowflake: four ingestion patterns (Openflow ListenOTLP, Collector→Kafka→Connector v4, custom exporter→Snowpipe Streaming HP, files→stage→COPY/Iceberg) plus the shared event-table-shaped shredding layer and Dynamic Table reporting gold layer
- `guide-ai-spend-consolidation` — Cross-platform AI usage and cost consolidation at user-level grain: pluggable adapter contract over vendor admin APIs (GitHub Copilot fully worked; ChatGPT Enterprise, Box AI, M365 Copilot, Anthropic Claude Enterprise and Claude Console, Cursor, and the three Google surfaces — Workspace Gemini, Code Assist, Vertex AI — as build specifications), Snowflake-native ACCOUNT_USAGE adapter needing no credentials, cost-model-aware unified fact distinguishing pure seat from seat-includes-usage from seat-includes-nothing, per-platform revision windows so restated feeds are not appended, identity spine, gold layer for five leadership decisions, semantic view and Cortex Agent, plus designed-in extensions for per-agent cost attribution and joining usage to operational outcomes

**Belongs here if:** the guide's primary job is configuring a named external product
to connect to Snowflake. Authentication setup, endpoint configuration, and integration
troubleshooting are the signals.

### Path 2 — Build Snowflake Data Pipelines

Workshops and demos covering Snowflake-native ingestion, transformation, change data
capture, orchestration, and incremental processing.

**Current members:**

- `guide-debezium-to-snowflake` — database CDC through Kafka into Snowflake
- `guide-otel-to-snowflake` — inbound OpenTelemetry pipelines: four ingestion patterns, the
  shared OTLP shredding layer, and a Dynamic Table gold layer (also in Path 1 and Path 6)
- `guide-ai-spend-consolidation` — multi-vendor admin-API ingestion: watermarked Python
  procedures, registry-driven adapters, VARIANT landing with SQL shredding, short-retention
  feed handling, and a Dynamic Table gold layer (also in Path 1 and Path 4)
- `guide-delta-sharing-ip-allowlist` — batch pull from a Delta Sharing provider into native
  tables: job service on a compute pool, freshness gating on the provider's own refresh marker,
  full-refresh overwrite-and-swap publication, plus the customer-NAT variant's external-stage
  landing, `_SUCCESS`-marker gating across two schedulers, and `COPY INTO` load
  (also in Path 1 and Path 5)
- `guide-shopify-multistore-snowflake` — multi-store Shopify ingestion: registry-driven
  per-store extraction on either path, watermarked Bulk API pulls with SECRET + EAI on the
  native path, and a Dynamic Table analytics layer conforming to one shared column contract
  (also in Path 1 and Path 6)

**Belongs here if:** the project's primary job is building or operating a
Snowflake-native data pipeline rather than configuring an external integration.

### Path 3 — Build a Production Cortex Agent

Guides covering the design, configuration, deployment, and extension of Cortex Agents.
Reading order within this path matters.

**Current members (in recommended reading order):**

1. `guide-model-agnostic-accuracy` — semantic view and agent configuration foundations

**Belongs here if:** the guide's primary job is building, configuring, deploying, or
extending a Cortex Agent or its supporting objects (semantic views, tools, search).

### Path 4 — Govern Snowflake Costs and Usage

Guides covering credit visibility, AI service governance, warehouse controls, and
compute rightsizing. Reading order within this path matters.

**Current members (in recommended reading order):**

1. `guide-snowflake-cost-visibility` — foundational: Budget objects, METERING_DAILY_HISTORY,
   Resource Monitors
2. `guide-cortex-access-control` — AI access, per-user limits, and usage observability
3. `guide-org-reporting` — multi-account visibility: ORGANIZATION_USAGE two-path decision,
   application/database roles, query discipline, materialization pattern
4. `guide-ai-spend-consolidation` — beyond Snowflake: consolidating ChatGPT Enterprise,
   Claude Enterprise, GitHub Copilot, Cursor, Box AI, M365 Copilot, and the Google AI
   surfaces alongside Cortex at user-level grain, with metered-versus-seat cost modeling
   (including the two seat-plus-meter shapes that break naive totals), departmental
   allocation, and seat utilization (also in Path 1 and Path 2)
5. `guide-snowflake-ml-lifecycle` — deployed-model cost: compute pool idle time versus service
   scale-to-zero, warehouse inference, training, monitor refresh, storage (also in Path 6)

**Belongs here if:** the guide's primary job is monitoring, alerting on, or limiting
Snowflake credit or AI token consumption.

### Path 5 — Secure Snowflake and Build an Audit Trail

Guides covering access control patterns, identity federation, and audit log export.
Each guide in this path is standalone — no required reading order.

**Current members:**

- `guide-snowflake-mcp-role-controls` — least-privilege MCP access role, OAuth role boundary, and named secondary-role ceiling
- `guide-cortex-access-control` — Who gets which part of the Cortex surface: `CORTEX_USER` vs `AI_FUNCTIONS_USER` vs `CORTEX_AGENT_USER` vs per-function grants vs model application roles, the secondary-role and IMPORTED PRIVILEGES bypasses, progressive rollout, per-surface spend limits, usage observability queries
- `guide-cortex-model-policy` — Approved-model-only policy: read-only inventory, catalog-generated commands, both PUBLIC grant paths, explicit approval of future models, non-admin verification, execution-context checks, and targeted recovery
- `guide-delta-sharing-ip-allowlist` — stable egress IP allowlisting for a third-party data feed: which Snowflake features have an allowlistable egress range and which do not, the shared-`/24` disclosure, the credential-retrieval versus data-plane allowlist distinction, and the customer-controlled NAT address as the alternative when a provider will not accept a shared range (also in Path 1 and Path 2)

**Belongs here if:** the guide's primary job is enforcing access boundaries, establishing
identity federation, or feeding an audit or SIEM system.

### Path 6 — Understand New Snowflake Capabilities

Guides that explain and position recent Snowflake announcements. No required reading
order — pick based on area of interest.

**Current members:**

- `guide-horizon-context-catalog` — Horizon Context, Cortex Sense, Apache Ossie, and documented vs unresolved agent security boundaries (Summit 2026)
- `guide-salesforce-v2-zero-copy` — Salesforce and Snowflake zero-copy directions, V2 migration, and connector decision framework (also in Path 1)
- `guide-cowork-easter-eggs` — status-aware CoWork feature surface: Deep Research, Artifacts and shared conversations, chart policies, User Skills, Automations, MCP, document generation, mobile, and cost controls
- `guide-org-reporting` — ORGANIZATION_USAGE primer: two access paths, premium vs non-premium, query discipline
- `guide-cube-snowflake-semantic-layer` — bi-directional Snowflake Semantic Views sync with Cube, push limitations, decoupled vs warehouse-native decision (also in Path 1)
- `guide-otel-to-snowflake` — observability data in Snowflake: what event tables are and are not, why the collector-contrib Snowflake component points the wrong way, and Observe as the first-party buy-side option (also in Path 1 and Path 2)
- `guide-shopify-multistore-snowflake` — the Openflow Shopify connector is Preview while
  Openflow Snowflake Deployments are GA; covers what that split means for a production
  commitment, the always-on cost floor, and why no non-CDC sizing heuristic exists
  (also in Path 1 and Path 2)
- `guide-snowflake-ml-lifecycle` — Snowflake ML end to end for teams evaluating against AWS:
  Feature Store, ML Jobs, Model Registry, warehouse and SPCS inference, task-graph retraining,
  ML Lineage, model monitors, a serving bake-off protocol instead of parity claims, cross-cloud
  registry patterns, and deployed-model cost drivers (also in Path 4)

**Belongs here if:** the guide's primary job is explaining a new Snowflake feature or
capability rather than configuring or building something.

---

## Maintenance Rules

Keep internal audit reports, migration narratives, review ledgers, session notes,
and maintenance decision logs outside this public repository. Public files must
serve readers or be necessary source, tests, automation, or contributor guidance.
Do not override local-only ignore rules to preserve internal work in Git.

### Reader site and retrieval

Keep guide Markdown authoritative. `site/build.mjs` generates the Pages presentation;
never hand-edit `site/.build/`. `site/publication.json` controls reader-only publishing
and enhanced reader pages. Run the site build, link checks, and browser tests
documented in `site/README.md` when changing navigation or publication rules.
Do not add agent instructions or hidden tooling to the published artifact.
Project retrieval discovers top-level guide/demo READMEs without a static allowlist.
Contributor setup belongs in CONTRIBUTING.md and must never run during retrieval.
Archive operations must record retirement routes in `site/retired.json` before moving
files; never remove old URLs without a reader-facing notice.

### When you add a new guide or demo

1. Determine which path(s) above it belongs to. A guide can appear in multiple paths
   if it genuinely serves multiple reader intents (e.g., `guide-ai-spend-consolidation`
   belongs in Paths 1, 2, and 4).
2. Add it to the **Current members** list in the relevant path section(s) above.
3. Ensure the `## Start Here` routing table leads to its catalog category; add a direct
   link only when the project changes a recommended reading sequence.
4. Add it to the `## Projects` table in `README.md` with the standard row format:
   `| [Readable title](guide-name/) | One-sentence purpose | Comma-separated topic tags |`
5. Update the `![Projects](...)` badge count in `README.md`.

### When you remove or archive a guide

1. Record retirement routes, then move the directory to ignored `_archive/`.
   Remove that local copy when a maintainer explicitly requests a purge; do not
   publish it or restore it into the active catalog.
2. Remove it from the **Current members** list in AGENTS.md.
3. Remove it from the `## Start Here` routing table and `## Projects` table in `README.md`.
4. Search for `guide-<name>` across all other guide READMEs and remove or redirect
   any `Related Guides` or `Before You Start` cross-references that pointed to it.
5. Update the `![Projects](...)` badge count.

### When a guide's expiry date passes

Retirement is the default, not automatic renewal. Follow the retirement steps
above unless a maintainer explicitly chooses to keep or merge the guide.
Renew only after substantive verification of its core claims and workflows:
keep review evidence outside the public repository, update the README's
`Last verified` date, and set expiry no later than 60 days after that review.
Formatting, ordinary commits, narrow corrections, publication, and merges do not
reset the clock. Preserve inherited review dates when merging material.
See `CONTRIBUTING.md` for verification evidence and legacy-baseline rules.

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
- `## Related Guides` section near the bottom — **public, stable external links only** (docs.snowflake.com, etc.). Do NOT link to sibling guides in this repo — they expire and rot. Use the [Start Here index](./README.md) for cross-guide navigation instead.
- `## External References` section at the end

Expiry dates: at most 60 calendar days from substantive verification (SFE S4),
regardless of feature maturity. Earlier deadlines remain earlier. README dates
and badges must agree; run
`python3 .github/scripts/expire-projects.py --check` before publication.

---

## Demo Format Standards

Each `demo-<name>/deploy_all.sql` must follow this structure exactly. Use
`demo-cortex-ai-cost-controls/deploy_all.sql` as the canonical reference.

### deploy_all.sql structure (required, in order)

**1. Header block** — block comment with:

- Demo name + attribution + expiry date on the first line
- `INSTRUCTIONS:` — "Open Snowsight → New Worksheet → Paste → Run All" + expected runtime
- `WHAT GETS CREATED:` — every object the script creates, by type
- `AFTER DEPLOY:` — numbered steps the user takes after the SQL finishes
- `PREREQUISITES:` — roles needed, API integrations, any manual pre-steps

**2. Expiration check SELECT** — runs immediately so the user sees a warning before anything is created:

```sql
SELECT
    '<YYYY-MM-DD>'::DATE AS expiration_date,
    CURRENT_DATE()       AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '<YYYY-MM-DD>'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF(...) < 0  THEN 'EXPIRED - Code may use outdated syntax.'
        WHEN DATEDIFF(...) <= 7 THEN 'EXPIRING SOON - ...'
        ELSE 'ACTIVE - ...'
    END AS demo_status;
```

**3. Minimal infrastructure** — only what is needed before the Git repository object can exist:

```sql
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE ...;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS ...;
```

**4. Git repository** — shared repo object; reuse across demos, do not create duplicates:

```sql
CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-public.git';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;
```

**5. EXECUTE IMMEDIATE FROM** — one call per sub-file, using the full stage path:

```sql
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-<name>/sql/...';
```

> **NEVER use bare relative paths** (`'sql/01_setup/...'`). Snowflake has no local
> filesystem — relative paths silently fail. The `@REPO/branches/main/...` form is
> the only syntax that works from a Snowsight worksheet.

**6. Final validation SELECT** — confirms objects were created and shows the next step:

```sql
SELECT
    '<Demo Name>' AS demo,
    (SELECT COUNT(*) FROM <schema>.<table1>) AS <label1>,
    ...
    '<next action>' AS next_step;
```

### sql/ subdirectory

The `sql/` subdirectory is correct and intentional — it keeps individual scripts focused
and independently runnable. `deploy_all.sql` is the **orchestrator**, not the inliner.
All SQL logic lives in `sql/`; `deploy_all.sql` only contains infrastructure setup,
the Git repo, `EXECUTE IMMEDIATE FROM` calls, and the validation query.

---

## Pre-commit Hooks

This repo uses `detect-secrets` and a custom account-name scanner. Common issues:

- **Account examples:** use `<org>-<account>` with angle brackets; actual account
  hostnames are blocked in every text-file type, including Markdown and HTML.
- **Public-content check:** run `python3 .github/scripts/check-public-content.py`.
  Review binary assets visually; text checks cannot establish their provenance.
- **Secret false positives:** add `# pragma: allowlist secret` inline comment.
- **`api_key` false positives:** use `api_key="placeholder"` with the allowlist comment.  # pragma: allowlist secret
