---
name: cortex-agent-versioning
description: "Guide to versioning Cortex Agents with GitHub. Use when: a customer or builder asks how to version a Cortex Agent, promote/rollback agent releases, commit LIVE to VERSION$N, alias/default a version, deploy agent_spec.yaml from GitHub, ADD VERSION FROM a Git repo, or wire agent CI/CD."
---

# Versioning Cortex Agents with GitHub

## Purpose

Help SEs position, and builders implement, a real release process for Cortex
Agents: the built-in commit-based version model, and how GitHub becomes the
source of truth via Snowflake's native Git integration. Includes a small
runnable example (ORDERS agent) that walks the full lifecycle.

## Architecture

Reference guide + runnable example, no long-lived deployed objects:

- `README.md` — model + lifecycle diagram; iterate-in-Snowflake vs Git-driven compared; Git↔Snowflake command map; gotchas.
- `specs/agent_spec.yaml` — the versioned source-of-truth spec (one Cortex Analyst tool over `ORDERS_SV`).
- `sql/01..06 + 99` — setup → create → iterate/commit/promote → git import → promote/rollback → inspect → teardown.
- `github-actions/deploy-agent.yml` — example tag-triggered CI/CD (reference only).

## Key Files

| File | Role |
|---|---|
| `README.md` | Explanation, both operating models, command map, gotchas |
| `specs/agent_spec.yaml` | Source-of-truth spec to version in Git |
| `sql/02_create_agent.sql` | `CREATE AGENT` → `VERSION$1` + `LIVE` |
| `sql/03_iterate_commit_promote.sql` | Snowflake-driven: edit LIVE → COMMIT → alias → default → resume dev |
| `sql/04_git_driven_import.sql` | API integration + GIT REPOSITORY + `ADD VERSION FROM @repo/...` |
| `sql/05_promote_rollback.sql` | Move `production` alias + `DEFAULT_VERSION` (both directions) |
| `sql/06_inspect.sql` | Read any version's spec verbatim from its stage |
| `github-actions/deploy-agent.yml` | Example CI/CD on release tag |
| `AGENTS.md` | Project instructions + verified-facts list |

## The mental model (lead with this)

Develop on the single mutable `LIVE` version. Freeze it into an immutable
`VERSION$N` with `COMMIT`. Put an `alias` (`production`) on that version and set
`DEFAULT_VERSION`. Promotion and rollback are the same move: repoint the alias
and/or default. GitHub fits because Snowflake reads `agent_spec.yaml` directly
from a `GIT REPOSITORY` stage — so a merged/tagged spec becomes a version.

## Decision shortcut

| Situation | Model | Why |
|---|---|---|
| Solo dev, prototype, demo | Iterate-in-Snowflake | Fastest loop; edit LIVE + COMMIT |
| >1 contributor, needs review/audit | Git-driven | PR review, diff history, reproducible imports |
| Automated release on tag | Git-driven + Actions | `FETCH` + `ADD VERSION FROM @repo/tags/...` |

## Extension Playbook: add another example tool or a new deployment target

1. **New tool on the agent** — edit `specs/agent_spec.yaml` (add a `tools[]` entry
   + matching `tool_resources` key), then mirror the change in
   `sql/03_iterate_commit_promote.sql`'s `MODIFY LIVE VERSION SET SPECIFICATION`
   so the two stay in sync. Keep `orchestration: auto`.
2. **New tool needs data** — add the object (table/semantic view/search service)
   to `sql/01_setup.sql` and its drop to `sql/99_teardown.sql`.
3. **Different Git provider** (GitLab/Bitbucket/Azure DevOps) — the model is
   identical; only the `API_ALLOWED_PREFIXES` and `ORIGIN` URL change in
   `sql/04_git_driven_import.sql`. Confirm the provider's prefix format against docs.
4. **New CI system** (not GitHub Actions) — the deploy step is always the same two
   commands: `ALTER GIT REPOSITORY ... FETCH` then `ADD VERSION FROM @repo/...`.
   Swap the runner; keep those commands.
5. Re-verify any changed command against `snowflake_product_docs` and update the
   verified-facts list in `AGENTS.md` with the date checked.

## Gotchas

- **`COMMIT` destroys `LIVE`** — follow with `ADD LIVE VERSION ... FROM LAST` to keep developing. #1 mistake.
- **`DEFAULT_VERSION` rejects aliases** — use `'VERSION$N'` / `FIRST` / `LAST`. No `UNSET`; use `= LAST`.
- **`ALIAS` is version-level** (`MODIFY VERSION SET ALIAS`); **`SPECIFICATION` is LIVE-only** (`MODIFY LIVE VERSION SET SPECIFICATION`). Wrong scope → error `001420`.
- **New spec fully replaces the old** — omitted fields are removed.
- **`DESCRIBE AGENT` shows DEFAULT, not LIVE** once versions exist — read the stage file for a specific version.
- **Stage import needs a file named exactly `agent_spec.yaml`**; unquoted aliases store UPPERCASE in stage paths.
- **Can't drop the default version** or a committed version that bases the current `LIVE` — change default first.
- **`MODIFY VERSION` needs a concrete `VERSION$N` or alias** — don't assume the `LAST` shortcut works there; in CI, query `SHOW VERSIONS` first for alias moves.
