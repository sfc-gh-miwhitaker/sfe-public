![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2026--05--02-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Cortex Code: Multiple Connections for Partner SEs

**Pair-programmed by SE Community + Cortex Code**
**Created:** 2026-04-02 | **Expires:** 2026-05-02 | **Status:** ACTIVE

A step-by-step workshop for Partner SEs who work across multiple customer Snowflake accounts. You'll walk out with a clean multi-connection setup, project-specific context isolation, and a reusable launch pattern for every engagement.

> **No support provided.** This content is for reference only. Review and validate before applying to any production workflow.

---

## Who This Is For

Partner SEs who juggle multiple customer accounts and need:

- Each project connected to the right Snowflake account automatically
- No risk of accidentally running queries against the wrong account
- Clean context separation: memory, sessions, and rules scoped per engagement
- Fast, reliable launch commands so spinning up on a new project takes seconds

**Already have Cortex Code installed?** Jump straight to [WORKSHOP.md](WORKSHOP.md).

**New to Cortex Code?** [Install the CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) first, then come back.

---

## Read the Source First

Before starting, skim the official reference for the two files this guide builds on:

- **[Snowflake CLI Connection Docs](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/specify-credentials/define-connections)** — Full `config.toml` field reference and authentication methods
- **[Cortex Code Configuration](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli)** — `--connection` flag, `SNOWFLAKE_CONNECTION` env var, `settings.json`

This guide does not re-explain these. It focuses on the multi-project patterns the docs don't cover.

---

## The Workshop

| Part | What You Build | Time |
|------|----------------|------|
| [1. Anatomy](prompts/01_anatomy.md) | Understand `connections.toml` and how CoCo reads it | 5 min |
| [2. Multi-customer Setup](prompts/02_connections_setup.md) | Add one connection per project/customer | 10 min |
| [3. Launch Patterns](prompts/03_cli_launch.md) | `cortex -c`, env var, and one-liner patterns | 10 min |
| [4. Project Lock with AGENTS.md](prompts/04_project_agents.md) | Pin a project directory to a specific connection | 10 min |
| [5. Environment Isolation](prompts/05_isolation.md) | Separate memory, sessions, and context per engagement | 10 min |

### What You'll Have After

| Artifact | Where |
|----------|-------|
| Named connection per customer | `~/.snowflake/config.toml` |
| Per-project AGENTS.md with connection hint | Each project root |
| Shell aliases for instant launch | `~/.zshrc` or `~/.bashrc` |
| Quick-reference card | `reference/` |

---

## Quick Start

```bash
cd guide-coco-connections
cortex
```

Then tell CoCo: *"Walk me through the multi-connection workshop step by step."*

Or open [WORKSHOP.md](WORKSHOP.md) and follow the parts in order.

---

## References

| Resource | URL |
|----------|-----|
| Cortex Code CLI docs | https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli |
| Snowflake CLI connection config | https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/specify-credentials/define-connections |
| Authentication methods | https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/specify-credentials/authenticate-snowflake |
