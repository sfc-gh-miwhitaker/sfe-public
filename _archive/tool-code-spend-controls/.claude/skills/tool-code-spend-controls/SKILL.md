---
name: tool-code-spend-controls
execution_mode: inline
---

# Cortex Code FinOps Governance Toolkit

## When to Use

- Customer asks about Cortex Code costs, spend visibility, or cost controls
- SE needs to demonstrate FinOps governance for Cortex Code (CLI or Snowsight)
- Customer wants per-user daily credit limits, budget notifications, or threshold alerts
- FinOps lead needs to set up proactive alerting before users are blocked by daily limits

## Architecture

- **`notebook.ipynb`** — Primary artifact: 3 sections (Spend Analysis → Per-User Limits → Threshold Notifications)
- **`deploy_all.sql`** — One-shot deploy: notebook from Git + notification objects (task, procedure, audit table)
- **`scenarios/`** — 6 scenario runbooks covering understand spend, set limits, get notified, automate, restrict access, reduce costs
- **`worksheets/`** — 8 standalone Snowsight SQL worksheets including per-user-limits.sql and notifications.sql

## Data Sources

- `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY`
- `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY`
- Account/user parameters: `CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER`, `CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER`

## Key Value: Per-User Limit Approach Alerts

Snowflake blocks users when they hit their rolling 24h daily credit limit but provides **no warning**. The toolkit deploys a serverless task that checks usage every 15 minutes and sends email alerts when any user reaches a configurable threshold (default 80%) of their limit.

## Gotchas

- `ACCOUNT_USAGE` views have ~1-2h latency; the alert task checks against delayed data
- `CREDITS_GRANULAR` is an OBJECT column; use `LATERAL FLATTEN` for per-model breakdown
- Per-user limits are account parameters, not budget features — they require `ACCOUNTADMIN`
- The notification task requires `SYSTEM$SEND_EMAIL` and a notification integration
- AI credit price is $2.00/credit on-demand; Capacity customers should adjust `ai_credit_price`

## Extension Playbook

1. **Add Slack/Teams alerts** — Replace email with webhook notification integration in the procedure
2. **Per-user overrides in the procedure** — Currently uses account defaults; extend to check user-level parameter overrides
3. **Custom budget notifications** — Same pattern as account budget but on `SNOWFLAKE.CORE.BUDGET` instances
4. **Historical trend dashboard** — Query the audit table for alert patterns over time
