---
name: cortex-ai-cost-controls
description: "AI cost monitoring dashboard on Snowflake App Runtime. Materialized ACCOUNT_USAGE views, per-user quotas (SNOWFLAKE.CORE.QUOTA), Recharts visualization. Use for: modifying SQL views, adding pages, extending quota integration, troubleshooting data layer refresh."
---

## Purpose

Read-only dashboard for Cortex AI spend attribution, per-user quota status, and trend analysis — deployed as a Next.js app on Snowflake App Runtime.

## Architecture

```
ACCOUNT_USAGE views (8 AI services)
        │
        ▼
SP_REFRESH_COST_MATERIALIZATION() ─── 15-min task (ships SUSPENDED)
        │
        ▼
MAT_* tables (5 materialized tables in CORTEX_AI_COST_CONTROLS schema)
        │
        ▼
Next.js App (querySnowflake, owner's rights) ─── Recharts UI (4 pages)
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | One-command SQL data layer orchestration |
| `sql/02_materialization/01_tables_and_task.sql` | Core: table DDL + refresh SP + task |
| `sql/03_quota_example/01_quota_setup.sql` | Native per-user quota configuration |
| `app/src/lib/snowflake.ts` | All SQL queries (centralized) |
| `app/src/app/page.tsx` | Overview dashboard (server component) |
| `app/app.yml` | Snowflake App Runtime manifest |
| `app/src/app/globals.css` | Dark theme tokens |

## Snowflake Objects

| Object | Type | Schema |
|--------|------|--------|
| `SFE_CORTEX_AI_COST_CONTROLS_WH` | Warehouse | — |
| `SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS` | Schema | — |
| `MAT_AI_USAGE_UNIFIED` | Table | CORTEX_AI_COST_CONTROLS |
| `MAT_AI_SPEND_DAILY` | Table | CORTEX_AI_COST_CONTROLS |
| `MAT_AI_SPEND_BY_USER` | Table | CORTEX_AI_COST_CONTROLS |
| `MAT_AGENT_ATTRIBUTION` | Table | CORTEX_AI_COST_CONTROLS |
| `SP_REFRESH_COST_MATERIALIZATION` | Procedure | CORTEX_AI_COST_CONTROLS |
| `TASK_REFRESH_COST_MATERIALIZATION` | Task | CORTEX_AI_COST_CONTROLS |
| `AI_COST_QUOTA` | SNOWFLAKE.CORE.QUOTA | CORTEX_AI_COST_CONTROLS |

## Gotchas

1. **SNOWFLAKE_COCO_USAGE_HISTORY** is the unified CoCo view (CLI + Desktop + Snowsight). If it doesn't exist in the target account, fall back to the 3 individual views.
2. **Quota methods** require the `QUOTA_CREATOR` database role — the setup script is exception-guarded.
3. **Refresh task ships SUSPENDED** — users must explicitly `ALTER TASK ... RESUME`.
4. **ACCOUNT_USAGE latency**: All AI views have ~1 hour lag. Materialized tables won't show data from the last hour.
5. **App uses owner's rights** — the service role needs `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE`.
6. **Model names in seed script**: Always verify with `SHOW CORTEX BASE MODELS` before changing. Pick cheapest GA model with broadest region availability.

## Adding a New Usage View

When Snowflake adds a new AI service usage view to ACCOUNT_USAGE:

1. Add a new CTE in `sql/02_materialization/01_tables_and_task.sql` inside `SP_REFRESH_COST_MATERIALIZATION`, following the pattern of existing CTEs (normalize to: service_type, user_id, user_name, credits, tokens, usage_time, request_id, role_name, user_tags, entity_name, interaction_interface)
2. Add the new CTE to the `UNION ALL` chain
3. Update `app/src/lib/snowflake.ts` types if new fields are needed
4. The dashboard pages auto-adapt via `service_type` grouping — no page changes needed unless you want a dedicated breakdown

## Adding a New Dashboard Page

1. Create `app/src/app/<pagename>/page.tsx` (server component for data fetching)
2. Create `app/src/app/<pagename>/<Name>Charts.tsx` (client component with `"use client"` for Recharts)
3. Add query function to `app/src/lib/snowflake.ts`
4. Add nav entry to `app/src/components/Nav.tsx`
