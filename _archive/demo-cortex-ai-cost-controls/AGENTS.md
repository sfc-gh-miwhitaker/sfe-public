# Cortex AI Cost Controls — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

Streamlit-in-Snowflake dashboard that reads LIVE SNOWFLAKE.ACCOUNT_USAGE Cortex
usage views to monitor, attribute, limit, and protect Cortex AI spend.

## Architecture

```
deploy_all.sql ──> shared infra (API integration, db, warehouse, Git repo, FETCH)
                   then EXECUTE IMMEDIATE FROM @SFE_DEMOS_REPO .../sql/01..05

sql/01_setup       schema + IMPORTED PRIVILEGES grant to SYSADMIN
sql/02_views       APP views over ACCOUNT_USAGE (V_AI_USAGE_UNIFIED is the workhorse)
sql/03_enforcement limits table, config, audit, V_LIMIT_STATUS, 2 procs, SUSPENDED task
sql/04_budget      custom AI_BUDGET (exception-guarded so deploy never breaks)
sql/05_streamlit   CREATE STREAMLIT ... FROM git stage + ADD LIVE VERSION
sql/99_optional    seed REAL AI calls (NOT run by deploy_all)

app/streamlit_app.py + app/pages/{1_Attribution,2_Limits,3_Runaway,4_Anomaly}.py
                   read the APP views; Limits/Runaway also CALL the procedures.
```

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CORTEX_AI_COST_CONTROLS
- Warehouse: SFE_CORTEX_AI_COST_CONTROLS_WH
- Streamlit: CORTEX_AI_COST_DASHBOARD (warehouse runtime)

## Conventions
- Reads LIVE data only — no synthetic tables. Views normalize the inconsistent
  source columns into (usage_day, service, user_name, credits).
- Enforcement is SIMULATE-ONLY by default; the task ships SUSPENDED. Never resume
  it or set SIMULATE_ONLY='FALSE' without explicit user intent.
- Deploy scripts run via EXECUTE IMMEDIATE FROM the Git stage — files must be
  pushed to GitHub `main` before `deploy_all.sql` can find them.

## Key Commands
- Deploy: open `deploy_all.sql` in Snowsight → Run All
- Teardown: `teardown_all.sql`
- Seed real usage (optional): `sql/99_optional/01_seed_real_usage.sql`

## When Helping with This Project
- Verify ACCOUNT_USAGE column names before editing views: AI Functions uses
  USER_ID (not USER_NAME); Analyst uses USERNAME; credit columns vary
  (CREDITS / TOKEN_CREDITS / CREDITS_USED).
- Use MERGE for upserts (no ON CONFLICT in Snowflake).
- Object grants go TO ROLE, never TO USER.
- Keep `deploy_all.sql` the single entry point; new SQL goes in `sql/##_*/` and
  gets an EXECUTE IMMEDIATE FROM line.

## Helping New Users

If the user seems confused or asks "what is this" / "how do I start":

1. **Greet warmly** and explain in one sentence: this is a live dashboard showing
   where your Snowflake Cortex AI credits are going and how to control them.
2. **Check deployment** — ask if they've run `deploy_all.sql` in Snowsight yet.
3. **Guide step-by-step** if not deployed: open Snowsight → new SQL worksheet →
   paste `deploy_all.sql` → click "Run All" (the play button with two arrows) →
   then Projects → Streamlit → CORTEX_AI_COST_DASHBOARD.
4. **Suggest what to try** — Overview for the spend picture; Limits to set a
   per-user cap; the optional seed script if the account has little AI usage.

**Assume no technical background.** Define terms: "Snowsight is the Snowflake web
interface where you run SQL."
