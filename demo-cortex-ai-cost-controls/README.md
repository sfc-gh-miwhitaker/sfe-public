![Demo](https://img.shields.io/badge/type-demo-blue) ![Snowflake App Runtime](https://img.shields.io/badge/runtime-App%20Runtime-29B5E8) ![Expires](https://img.shields.io/badge/expires-2027--02--25-yellow) ![Status](https://img.shields.io/badge/status-ACTIVE-green)

# Cortex AI Cost Controls Dashboard

Read-only monitoring dashboard for Cortex AI spend attribution, per-user quota status, and trend analysis. Built as a Next.js app on Snowflake App Runtime.

**Audience:** Snowflake administrators, FinOps teams, AI governance leads.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-08-25 | **Expires:** 2027-02-25 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Quick Start

### 1. Deploy the SQL data layer

```sql
-- In Snowsight or SnowSQL, from a git stage or local file:
EXECUTE IMMEDIATE FROM 'deploy_all.sql';
```

This creates:
- Schema `SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS`
- 5 materialized tables pre-aggregating ACCOUNT_USAGE data
- A 15-minute refresh task (ships SUSPENDED — resume when ready)
- A per-user quota example (`SNOWFLAKE.CORE.QUOTA`)

### 2. Deploy the React app

```bash
cd app
snow app setup
snow app deploy
snow app open
```

### 3. (Optional) Seed usage data

If your account has no AI usage history yet:

```sql
EXECUTE IMMEDIATE FROM 'sql/99_optional/01_seed_real_usage.sql';
```

Wait ~1 hour for data to appear in ACCOUNT_USAGE views, then:

```sql
CALL SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS.SP_REFRESH_COST_MATERIALIZATION();
```

### 4. Activate the refresh task

```sql
ALTER TASK SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS.TASK_REFRESH_COST_MATERIALIZATION RESUME;
```

---

## Architecture

```
ACCOUNT_USAGE views ──► Refresh Task (15 min) ──► Materialized Tables ──► React App
                                                                            │
SNOWFLAKE.CORE.QUOTA ──────────────────────────────────────────────────────►│
```

| Component | Technology |
|-----------|-----------|
| Data layer | Materialized tables + SQL stored procedure + scheduled task |
| Cost governance | Native per-user quotas (`SNOWFLAKE.CORE.QUOTA`) |
| Frontend | Next.js 15 + React 19 + Recharts |
| Deployment | Snowflake App Runtime (`snow app deploy`) |
| Auth | Automatic SSO (Snowflake handles OAuth token injection) |

## Pages

| Page | What it shows |
|------|--------------|
| **Overview** | KPI cards (total credits, daily avg, unique users) + daily line chart + stacked bar by service |
| **Attribution** | Top users, per-user table with cost-center from USER_TAGS, agent attribution with interaction_interface |
| **Quotas** | Per-user quota status, blocked users, utilization — or guidance if no quotas configured |
| **Trends** | 90-day area chart with anomaly threshold, anomaly log table, week-over-week comparison |

## Key Modernizations (vs. prior version)

| Before | After |
|--------|-------|
| Custom enforcement (SP + task + audit table) | Native `SNOWFLAKE.CORE.QUOTA` with built-in block enforcement |
| `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` | `SNOWFLAKE_COWORK_USAGE_HISTORY` |
| 2 separate CoCo views (CLI + Snowsight) | Unified `SNOWFLAKE_COCO_USAGE_HISTORY` |
| Manual credit calculation | `TOKEN_CREDITS` column (direct) |
| Custom tag FLATTEN for cost-center | `USER_TAGS` / `AGENT_TAGS` (platform-resolved) |
| Streamlit-in-Snowflake | Next.js on Snowflake App Runtime |

## Teardown

```sql
EXECUTE IMMEDIATE FROM 'teardown_all.sql';
```

```bash
cd app && snow app teardown
```

## Development Tools

This project includes AI assistant configuration for collaborative development:

- `AGENTS.md` — Project-specific instructions for AI coding assistants
- `.claude/skills/cortex-ai-cost-controls/SKILL.md` — Detailed project skill (architecture, key files, extension playbooks)
- `ELI5.md` — Plain-language companion explaining the project without jargon

## Related Guides

- [Per-user quotas documentation](https://docs.snowflake.com/en/user-guide/budgets/per-user-quotas)
- [Snowflake App Runtime getting started](https://docs.snowflake.com/en/developer-guide/snowflake-app-runtime/getting-started)
- [CORTEX_AGENT_USAGE_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_agent_usage_history)
- [SNOWFLAKE_COWORK_USAGE_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/snowflake_cowork_usage_history_view)
