---
name: demo-coco-governance-github
description: GitHub-powered project tooling for Cortex Code. Use when reviewing SQL against project standards, working with the demo's sample tables, extending AGENTS.md rules, or understanding the dual-surface (CLI + Snowsight) architecture.
---

## Purpose

Demonstrates how `AGENTS.md` and custom skills in a GitHub repo deliver consistent Cortex Code standards across CLI and Snowsight workspaces.

## Architecture

Three layers, each optional:

1. **Project files** (`AGENTS.md` + this skill) -- Git delivers them to both Cortex Code surfaces
2. **GitHub management** -- PRs for standards changes, Issues for gap tracking, MCP for CLI integration
3. **Intune enterprise** -- `managed-settings.json` via MDM for org-level enforcement

Cortex Code reads `AGENTS.md` automatically from a cloned repo (CLI) or a Git-connected workspace (Snowsight). No Cortex Agent or custom SQL function required -- the files ARE the tooling.

## Key Files

| File | Role |
|------|------|
| `AGENTS.md` | Project standards (always-on, loaded every conversation) |
| `.claude/skills/.../SKILL.md` | This skill -- SQL review procedure (on-demand) |
| `deploy_all.sql` | Creates Git repo stage + sample schema with tables |
| `teardown_all.sql` | Drops all demo objects |
| `sql/01_setup/01_create_demo_objects.sql` | Schema, warehouse, CUSTOMERS/ORDERS/PRODUCTS with seed data |
| `docs/01-PROJECT-TOOLING.md` | Act 1: CLI and Snowsight dual-surface walkthrough |
| `docs/02-GITHUB-TEAM-MANAGEMENT.md` | Act 2: five GitHub features for team management |
| `docs/03-INTUNE-ENTERPRISE.md` | Act 3: Intune managed-settings nod |
| `reference/mcp-github-*.json` | GitHub MCP server configs (1Password and PAT) |
| `reference/intune-config.json` | Intune deployment template |

## Snowflake Objects

| Object | Name | Purpose |
|--------|------|---------|
| Database | `SNOWFLAKE_EXAMPLE` | Shared across all demos |
| Schema | `COCO_GOVERNANCE_GITHUB` | This demo's workspace |
| Warehouse | `SFE_COCO_GOVERNANCE_GITHUB_WH` | XSMALL, 60s auto-suspend, 120s timeout |
| Table | `CUSTOMERS` | 5 rows, sample customer dimension |
| Table | `PRODUCTS` | 4 rows, sample product dimension |
| Table | `ORDERS` | 9 rows, sample order fact table |

## SQL Review Procedure (On-Demand)

When asked to review SQL, run through these checks against the standards in AGENTS.md:

1. **SELECT * check** -- flag and list explicit columns from the target table
2. **Sargable predicates** -- flag `YEAR(col)`, `MONTH(col)`, `UPPER(col)` in WHERE clauses; show range alternative
3. **QUALIFY usage** -- flag subqueries that re-filter window functions; show QUALIFY rewrite
4. **Join type safety** -- flag implicit casts between join keys
5. **Timeout safety** -- for warehouse DDL, verify STATEMENT_TIMEOUT_IN_SECONDS is set
6. **Naming conventions** -- warehouses `SFE_<PROJECT>_WH`, tables `RAW_`/`STG_`/`<ENTITY>`
7. **Object comments** -- every CREATE needs `COMMENT = 'DEMO: ...'` with expiration
8. **Security** -- no hardcoded credentials (`ghp_`, `sk-`, passwords), no account identifiers

Report format: PASS or NEEDS FIXES with `[QUALITY]`/`[NAMING]`/`[SECURITY]` tags per issue.

## How to Add a New Standard

1. Add the rule to `AGENTS.md` under the appropriate section (SQL Standards, Security, Naming)
2. Add a corresponding check to the SQL Review Procedure above
3. Open a PR so the team reviews the new rule
4. After merge, every team member gets the update on next `git pull` or Snowsight sync

## Gotchas

- This skill reviews against THIS project's standards. Other projects have different conventions.
- `AGENTS.md` rules are always-on (every session). This skill is on-demand (invoked by trigger or explicit request).
- After context compaction in long sessions, re-read `AGENTS.md` if standards seem forgotten.
- The sample tables use AUTOINCREMENT PKs -- don't reference specific IDs in examples since they vary per deployment.
