# Monorepo Conventions

This document records the conventions applied during the deduplication cleanup of
`demo-campaign-engine` and serves as a reference for future demo projects in the
`sfe-public` monorepo.

## Principles

### Self-Containment

Every project -- and ideally every SQL script within a project -- must work when
run independently. A user should be able to open any script in Snowsight, click
**Run All**, and get a working result without first running another project's
scripts.

This means `CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE` may appear in both
`deploy_all.sql` and `sql/01_setup/01_create_schema.sql` within the same
project. That is intentional, not duplication.

Never assume another project or `shared/sql/00_shared_setup.sql` has already run.
The shared setup creates the `SFE_GIT_API_INTEGRATION` and is listed as a
prerequisite in the deployment guide, but individual scripts should not depend on
it for database or warehouse creation.

### Idempotency

Every statement must be safe to re-run:

- `CREATE ... IF NOT EXISTS` for databases, schemas, warehouses, Git repos
- `CREATE OR REPLACE` for views, procedures, functions, dynamic tables,
  Streamlit apps, Cortex agents
- `INSERT OVERWRITE` for sample data loads
- `DROP ... IF EXISTS` for teardown

Err on the side of caution. A user re-running `deploy_all.sql` on top of an
existing deployment should get the same result without errors.

### No Dead Code

If something cannot execute in the monorepo layout, delete it. Dead code creates
confusion and drift risk. Two examples removed from this project:

| Removed file | Why |
|---|---|
| `.github/workflows/expire-demo.yml` | GitHub Actions only discovers workflows at the **repo root** `.github/workflows/`, not inside subdirectories. A nested workflow file never fires. |
| `sql/99_cleanup/teardown_all.sql` | Mirrored the root `teardown_all.sql` but was never referenced by `deploy_all.sql`. Two copies of teardown logic drift independently. |

## Where Things Live

| Artifact | Location | Notes |
|---|---|---|
| GitHub Actions workflows | Repo root `.github/workflows/` only | Subdirectory workflows are invisible to GitHub |
| Deployment entry point | `demo-*/deploy_all.sql` | Users paste this into Snowsight |
| Teardown entry point | `demo-*/teardown_all.sql` | One copy at the project root; no mirrors |
| SQL scripts (EXECUTE IMMEDIATE FROM) | `demo-*/sql/NN_category/NN_name.sql` | Called by `deploy_all.sql` via Git stage |
| Streamlit source | `demo-*/streamlit/` | Deployed from Git stage by a SQL script |
| Shared infra | `shared/sql/00_shared_setup.sql` | Creates `SFE_GIT_API_INTEGRATION`; listed as a prerequisite, never assumed |
| Semantic views | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS` schema | Shared schema, created idempotently by each project that needs it |

## Expiration Handling

Demo expiration is enforced at deploy time by the SQL-level check in
`deploy_all.sql`:

```sql
SET DEMO_EXPIRES = '2026-05-01';
DECLARE
  demo_expired EXCEPTION (-20001, 'DEMO EXPIRED - contact owner');
BEGIN
  IF (CURRENT_DATE() > $DEMO_EXPIRES::DATE) THEN
    RAISE demo_expired;
  END IF;
END;
```

This is the monorepo mechanism. A repo-root GitHub Actions workflow that scans
all `demo-*/deploy_all.sql` files for expiration dates could complement this
in the future, but that is a separate initiative and does not belong inside any
individual project directory.

## Checklist for New Monorepo Demos

- [ ] `deploy_all.sql` at project root with expiration check, warehouse
      bootstrap, Git fetch, and EXECUTE IMMEDIATE FROM chain
- [ ] `teardown_all.sql` at project root -- single copy, no mirrors in `sql/`
- [ ] Every SQL script uses `IF NOT EXISTS` / `CREATE OR REPLACE` / `DROP IF
      EXISTS` as appropriate
- [ ] No `.github/` directory inside the project (workflows live at repo root)
- [ ] `shared/sql/00_shared_setup.sql` listed as a prerequisite in
      `docs/01-DEPLOYMENT.md`, never silently assumed
- [ ] Database and warehouse creation repeated in setup scripts for
      standalone runnability
- [ ] `teardown_all.sql` drops only project-specific objects; never drops
      `SNOWFLAKE_EXAMPLE`, shared schemas, or API integrations
- [ ] Root `README.md` updated with the new project entry
