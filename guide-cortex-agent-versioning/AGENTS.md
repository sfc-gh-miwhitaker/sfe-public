# Versioning Cortex Agents with GitHub — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Reference guide with a small runnable example. Thesis: **Snowflake agents have a
built-in commit-based version model** (`LIVE` → `COMMIT` → immutable `VERSION$N`
→ alias → default), and GitHub plugs into it natively because Snowflake can read
`agent_spec.yaml` straight from a `GIT REPOSITORY` stage (`ADD VERSION FROM @repo/...`).

Two operating models, same primitives:
- **Iterate-in-Snowflake** — edit `LIVE`, `COMMIT`, alias, set default.
- **Git-driven** — edit `agent_spec.yaml` in GitHub, PR, then import a version
  from the repo, bypassing `LIVE`. Recommended once >1 person contributes.

Layout:
- `README.md` — model explanation, both flows compared, Git↔Snowflake command map, gotchas.
- `specs/agent_spec.yaml` — the versioned source-of-truth spec (one Cortex Analyst tool).
- `sql/01..06 + 99` — self-contained runnable lifecycle over a tiny ORDERS table + semantic view.
- `github-actions/deploy-agent.yml` — example CI/CD (reference; intentionally NOT under `.github/workflows/`).

## Verified facts (checked against Snowflake docs 2026-07-01 — re-verify, this area moves fast)

- `CREATE AGENT` (versioning enabled) creates **`VERSION$1` + `LIVE` together**.
- `ALTER AGENT COMMIT` snapshots `LIVE` → next `VERSION$N` and **destroys `LIVE`**.
  Recreate with `ALTER AGENT ADD LIVE VERSION [<alias>] FROM LAST`.
- `SET DEFAULT_VERSION` accepts `'VERSION$N'`, `FIRST`, `LAST` — **not** user aliases.
  There is no `UNSET DEFAULT_VERSION`; use `= LAST` to auto-follow newest.
- `ALIAS` is version-level: `MODIFY VERSION <v> SET ALIAS = <a>` (committed) or
  `MODIFY LIVE VERSION SET ALIAS`. `ALTER AGENT SET ALIAS` → error `001420`.
- `SPECIFICATION` is `LIVE`-only (`MODIFY LIVE VERSION SET SPECIFICATION`); new spec
  **fully replaces** the old. `ALTER AGENT SET SPECIFICATION` → error `001420`.
- After any committed version exists, unversioned `agent:run` and `DESCRIBE AGENT`
  resolve to **DEFAULT**, not `LIVE`. Read a specific version's spec from the stage
  (`snow://agent/<name>/versions/<v>/agent_spec.yaml`).
- Git import: `ALTER AGENT <name> ADD VERSION FROM @<repo>/branches/<b>/<path>` or
  `.../tags/<t>/<path>`; only `agent_spec.yaml` is copied. `CREATE AGENT ... FROM @stage`
  bootstraps a new agent from a staged spec (infra-as-code).
- Native Git: `CREATE API INTEGRATION ... API_PROVIDER = git_https_api` (GitHub App:
  `API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)`; or PAT via
  `ALLOWED_AUTHENTICATION_SECRETS` + `GIT_CREDENTIALS`) → `CREATE GIT REPOSITORY` →
  `ALTER GIT REPOSITORY <r> FETCH`.
- Versioned run REST: `POST /api/v2/databases/{db}/schemas/{schema}/agents/{name}/versions/{version}:run`;
  `{version}` = `VERSION$N` / alias / `FIRST|LAST|DEFAULT|LIVE`; URL-encode `$` as `%24`.
- `MODIFY VERSION` targets committed versions and takes a `<version_name>` (system id or
  alias) — do **not** assume it accepts the `LAST` shortcut; capture the concrete
  `VERSION$N` for alias moves in CI.

## Conventions

- Placeholders: `<UPPERCASE_WITH_UNDERSCORES>`. Example identifiers are self-contained
  (`AGENT_VERSIONING_DEMO.DEMO`, `AGENT_VERSIONING_WH`, `ORDERS_AGENT`) — safe to run as-is.
- Agent specs use `orchestration: auto` (never a pinned model — region portability).
- The created-date verification note in the README header is load-bearing — keep it.
- `agent_spec.yaml` filename is mandatory for stage imports; don't rename it in `specs/`.

## Key Commands

This is a guide; the runnable parts are the numbered SQL scripts. Run them in a
**sandbox with agent versioning enabled** — not Snowhouse or a shared prod account.
Order: `01 → 02 → 03 → (04 needs ACCOUNTADMIN) → 05 → 06`, and `99` to tear down.
