# Cortex AI Functions — Cost Governance Toolkit

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

Notebook + Streamlit dashboard for monitoring, alerting, and controlling Cortex AI Function spend. All analytics read from `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY` — no staging tables.

## Architecture
- `deploy_all.sql` — creates schema, notebook, and Streamlit from Git stage
- `notebook.ipynb` — SQL cells: monitoring queries + governance setup (alerts, per-user limits, runaway detection)
- `streamlit_app.py` — interactive dashboard with day/week/month/year usage views per user
- Data source: `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY` joined with `SNOWFLAKE.ACCOUNT_USAGE.USERS`

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: AI_SPEND_CONTROLS
- Warehouse: SFE_AI_SPEND_CONTROLS_WH

## Conventions
- Notebook uses SQL cells (`%%sql`), not Python/Snowpark
- Streamlit uses `session.sql(...).to_pandas()` for all queries
- `CREDITS` column is the primary cost metric (not token counts)
- AI credit price default: $2.00/credit (on-demand global rate)
- View latency: up to 60 minutes; running queries updated every 30 minutes
- The CORTEX_AI_FUNCTIONS_USAGE_HISTORY view only includes usage after January 5, 2026

## Key Commands
- Deploy: paste `deploy_all.sql` into Snowsight → Run All
- Teardown: paste `teardown_all.sql` into Snowsight → Run All
- Prerequisite: `GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>`

## Governance Objects Created by Notebook
The notebook's governance cells create these objects when run (user opt-in):
- `AI_FUNCTIONS_ALERT_STATE` table — dedup monthly alerts
- `AI_FUNCTIONS_ACCESS_CONTROL` table — per-user spending limits
- `SFE_AI_COST_ALERTS` notification integration — email delivery
- `SEND_MONTHLY_SPEND_ALERT` procedure
- `GRANT_AI_FUNCTIONS_ACCESS` / `GRANT_ALL_ENTITLED_USERS` procedures
- `MONITOR_AND_CANCEL_RUNAWAY_QUERIES` procedure
- `AI_FUNCTIONS_MONTHLY_SPEND_ALERT` alert (hourly)
- `MONTHLY_AI_FUNCTIONS_ACCESS_REFRESH` / `MONITOR_RUNAWAY_AI_QUERIES` tasks
- `AI_FUNCTIONS_USER_ROLE` role

## Helping New Users
If the user seems confused or asks basic questions:
1. Explain this toolkit monitors Cortex AI Function costs (AI_COMPLETE, AI_SUMMARIZE, etc.)
2. Check if they've run `deploy_all.sql` in Snowsight yet
3. Walk them through opening Snowsight → SQL worksheet → paste → Run All
4. After deploy, suggest opening the notebook first for monitoring, then the Streamlit dashboard for interactive analysis
