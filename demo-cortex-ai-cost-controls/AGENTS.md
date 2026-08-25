<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Do not duplicate them here. -->

# demo-cortex-ai-cost-controls — AI Assistant Instructions

## What This Is

A read-only dashboard for monitoring Cortex AI credit consumption, per-user attribution, quota enforcement status, and spend trends. Built on Snowflake App Runtime (Next.js).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ SNOWFLAKE BACKEND                                            │
│                                                              │
│  ACCOUNT_USAGE views ──► SP_REFRESH_COST_MATERIALIZATION()  │
│  (8 AI usage views)       (15-min task)                     │
│         │                       │                           │
│         ▼                       ▼                           │
│  SNOWFLAKE.CORE.QUOTA    MAT_* tables (5 tables)           │
│  (native enforcement)          │                           │
│                                │                           │
├────────────────────────────────┼───────────────────────────┤
│ SNOWFLAKE APP RUNTIME          │                           │
│                                ▼                           │
│  Next.js Server ──► querySnowflake() ──► React + Recharts │
│  (owner's rights)                                          │
└─────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `deploy_all.sql` | One-command SQL data layer deploy |
| `sql/02_materialization/01_tables_and_task.sql` | Core: table DDL + refresh SP + task |
| `sql/03_quota_example/01_quota_setup.sql` | Native per-user quota configuration |
| `app/src/lib/snowflake.ts` | All SQL queries centralized |
| `app/src/app/page.tsx` | Overview dashboard (server component) |
| `app/app.yml` | Snowflake App Runtime manifest |

## Conventions

- SQL: All column references are explicit (no `SELECT *`)
- SQL: Views use `TOKEN_CREDITS` directly (not manual rate math)
- SQL: `USER_TAGS` for attribution (platform-resolved, no custom FLATTEN)
- App: Server Components for data fetching, Client Components for charts
- App: Owner's rights for all queries (admin dashboard, not per-user)
- Charts: Recharts with dark theme (matches `globals.css` variables)

## Important Gotchas

1. `SNOWFLAKE_COCO_USAGE_HISTORY` is the **unified** CoCo view (CLI + Desktop + Snowsight). If it doesn't exist in the account, fall back to the 3 individual views.
2. Quota methods (`!ADD_SHARED_RESOURCE`, `!SET_PER_USER_LIMIT`, etc.) require the `QUOTA_CREATOR` database role — the setup script is exception-guarded.
3. The refresh task ships **SUSPENDED** for demo safety. Users must explicitly resume it.
4. `ACCOUNT_USAGE` views have latency: AI Functions = 1hr, Agents = 1hr, CoWork = 1hr, CoCo = 1hr.

## Extension Ideas

- Add caller's rights mode for per-user self-service view
- Add webhook notification integration for Slack/Teams alerts
- Add cost-center drill-down using AGENT_TAGS hierarchy
- Add quota projected-spend visualization from GET_SPENDING_DETAILS_BY_USERS
