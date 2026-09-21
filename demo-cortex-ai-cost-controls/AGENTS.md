<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Do not duplicate them here. -->

# demo-cortex-ai-cost-controls — AI Assistant Instructions

## What This Is

A read-only dashboard for monitoring Cortex AI credit consumption, per-user attribution, quota enforcement status, and spend trends. Built on Snowflake App Runtime (Next.js).

## Architecture

```text
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
| ------ | --------- |
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
4. `ACCOUNT_USAGE` latency varies by view (commonly ~45 minutes to 3 hours, some views up to 24 hours) — always check the specific view's documented latency rather than assuming one number. For the four views this demo reads: Agents, CoWork, and CoCo are each documented at up to 1 hour; `CORTEX_AI_FUNCTIONS_USAGE_HISTORY` publishes no single latency figure and refreshes in-flight rows every 2 minutes on a 5-minute SLA.
5. `SNOWFLAKE_COCO_USAGE_HISTORY` carries `USER_NAME` and a first-class `INTERFACE` column directly — do not join to `USERS` or dig through `METADATA` for them. The view that lacks `USER_NAME` is `CORTEX_AI_FUNCTIONS_USAGE_HISTORY`. `USAGE_TIME` is `TIMESTAMP_TZ` while the other three views use `TIMESTAMP_LTZ`; cast explicitly. Exclude `USER_ID = 0` (Snowflake-internal, not a person).

## Extension Ideas

- Add caller's rights mode for per-user self-service view
- Add webhook notification integration for Slack/Teams alerts
- Add cost-center drill-down using AGENT_TAGS hierarchy
- Add quota projected-spend visualization from GET_SPENDING_DETAILS_BY_USERS
