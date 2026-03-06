# Secrets Rotation Workbook

![Expires](https://img.shields.io/badge/Expires-2026--04--05-orange)

> TOOL PROJECT - EXPIRES: 2026-04-05
> This tool uses Snowflake features current as of March 2026.

> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

**Pair-programmed by:** SE Community + Cortex Code
**Created:** 2026-03-06 | **Expires:** 2026-04-05 | **Status:** ACTIVE

A Snowflake Native Notebook that walks through rotating key-pair credentials and Programmatic Access Tokens (PATs) for service accounts using AWS Secrets Manager. Creates a purpose-built example service user (`SFE_SVC_ROTATION_EXAMPLE`) so you can see every step live, then adapt it for your own accounts.

## Quick Start

**Get just this tool:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) tool-secrets-rotation-aws
cd sfe-public/tool-secrets-rotation-aws
```

## First Time Here?

1. **Deploy** -- Copy `deploy_all.sql` into Snowsight, click "Run All"
2. **Open the notebook** -- Snowsight > Projects > Notebooks > `SECRETS_ROTATION_WORKBOOK`
3. **Run cells step by step** -- the notebook creates an example service user and walks through both rotation patterns
4. **Cleanup** -- Run `teardown_all.sql` when done

## What's Inside the Notebook

| Section | What Happens |
|---------|-------------|
| Service Account Setup | Creates `SFE_SVC_ROTATION_EXAMPLE` with network policy, auth policy, and rotator role |
| Pattern 1: Key-Pair | Assigns RSA public key, verifies fingerprint, explains AWS Secrets Manager native rotation |
| Pattern 2: PAT | Creates a PAT, rotates it live, shows before/after token state |
| Monitoring | 10 SQL queries: PAT inventory, expiration alerts, stale tokens, login audit, fingerprint verification |
| Security Checklist | Production readiness checklist and gotchas table |

Architecture diagrams (Mermaid) are in [`diagrams.md`](diagrams.md) -- they render on GitHub but not inside Snowflake Notebooks.

## Prerequisites

- ACCOUNTADMIN (or USERADMIN + SECURITYADMIN + SYSADMIN) to create the example objects
- A warehouse (uses shared `SFE_TOOLS_WH`)

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skill teaching the AI this project's patterns
- **Cortex Code in Snowsight** -- Open in a Workspace for AI-assisted development
- **Cursor** -- Open locally for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)

## References

- [Key-Pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)
- [Programmatic Access Tokens](https://docs.snowflake.com/en/user-guide/programmatic-access-tokens)
- [ALTER USER ... ROTATE PAT](https://docs.snowflake.com/en/sql-reference/sql/alter-user-rotate-programmatic-access-token)
- [CREDENTIALS View](https://docs.snowflake.com/en/sql-reference/account-usage/credentials)
- [Snowflake Key Pair (AWS Secrets Manager)](https://docs.aws.amazon.com/secretsmanager/latest/userguide/mes-partner-Snowflake.html)
- [Snowflake Notebooks](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks)
