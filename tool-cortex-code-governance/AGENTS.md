# Cortex Code FinOps Governance Toolkit — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Notebook-first FinOps toolkit with scenario documentation and SQL worksheets.

```
notebook.ipynb        — Primary artifact: 3 sections (~36 cells)
                        Section A: Spend Analysis (existing)
                        Section B: Per-User Daily Limits (new)
                        Section C: Threshold Notifications (new)
deploy_all.sql        — One-shot Snowsight deploy: notebook + notification objects
scenarios/            — 6 scenario runbooks (markdown, CoCo walkthrough)
worksheets/           — 8 standalone Snowsight SQL worksheets
```

Data flow: `SNOWFLAKE.ACCOUNT_USAGE` views + account/user parameters → notebook → optional Snowflake objects (task, procedure, audit table, notification integration).

## Data Sources

- `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY` — terminal / `snow` CLI usage
- `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` — browser IDE (Snowsight) usage
- Schemas are identical: USER_ID, REQUEST_ID, USAGE_TIME, TOKEN_CREDITS, TOKENS, CREDITS_GRANULAR (OBJECT), TOKENS_GRANULAR (OBJECT)
- Account parameters: `CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER`, `CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER`

## Objects Created

Section C of the notebook and `worksheets/notifications.sql` create:
- Schema `SNOWFLAKE_EXAMPLE.CORTEX_CODE_GOVERNANCE`
- Table `CORTEX_CODE_LIMIT_ALERTS` (audit log)
- Procedure `CORTEX_CODE_LIMIT_ALERT_CHECK` (checks usage vs limits, sends email)
- Task `CORTEX_CODE_LIMIT_ALERT_TASK` (serverless, runs every 15 min)
- Notification integration `cortex_code_budget_email_int`

## Conventions

- Notebook connects via `snowflake.snowpark.context.get_active_session()`
- AI credit price default: $2.00/credit (global on demand, Table 2b of consumption table)
- Dollar cost = `TOKEN_CREDITS * ai_credit_price`
- Model pricing reference: Table 6(e) of Snowflake Service Consumption Table (April 1, 2026)
- SQL files are standalone — users run against their own account
- Placeholders use `<angle_bracket>` format — never hardcoded customer values
- Destructive operations (teardown, DROP, REVOKE) are commented out

## Key Commands

```bash
# One-shot deploy (Snowsight): paste deploy_all.sql → Run All
# Manual notebook deploy: Snowsight > Projects > Notebooks > + > Import .ipynb
# CoCo walkthrough:
cortex "Walk me through the set-a-limit scenario in the Cortex Code governance toolkit"
```

## Required Privileges

```sql
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;
-- Sections B and C require ACCOUNTADMIN
```
