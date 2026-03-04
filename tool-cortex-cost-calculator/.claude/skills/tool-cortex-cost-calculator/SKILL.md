---
name: tool-cortex-cost-calculator
description: "Cortex spend attribution dashboard with forecasting. Triggers: cortex cost, cortex credits, cortex spend, cost calculator, cost attribution, cost forecasting, ACCOUNT_USAGE metering, cortex monitoring, streamlit cost dashboard, ML.FORECAST."
---

# Cortex Cost Calculator

## Purpose

Cortex spend attribution dashboard with 22 monitoring views, user-level attribution, ML.FORECAST 12-month projections, anomaly detection, and Streamlit visualization. Git-integrated deployment with config table for SE two-account workflows.

## When to Use

- Adding new Cortex service monitoring views
- Extending the Streamlit dashboard
- Working with the forecasting model or anomaly detection
- Adapting for customer-facing cost proposals

## Architecture

```
SNOWFLAKE.ACCOUNT_USAGE views (45min-3hr latency)
  ├── METERING_DAILY_HISTORY
  ├── WAREHOUSE_METERING_HISTORY
  └── Various serverless metering views
       │
       ▼
22 Monitoring Views (Cortex services breakdown)
       │
       ▼
CORTEX_COST_SNAPSHOTS table (daily snapshots via serverless task)
       │
       ▼
ML.FORECAST model (12-month projections)
       │
       ▼
Streamlit Dashboard (8 tabs)
  ├── Executive Summary
  ├── POC → Production
  ├── 12-Month Forecast
  ├── User Attribution
  ├── Historical Analysis
  ├── AISQL Functions
  ├── Cost Projections
  └── Export & Proposal
```

## Key Files

| File | Purpose |
|------|---------|
| `sql/00_config/config.sql` | Config table with MERGE upsert + GET_CONFIG helper |
| `sql/01_deployment/deploy_cortex_monitoring.sql` | 22 views, snapshot table, task, ML.FORECAST |
| `sql/02_utilities/export_metrics.sql` | 3 export options, SE two-account workflow |
| `sql/03_monitoring/view_cost_anomalies.sql` | Week-over-week anomaly detection |
| `streamlit/cortex_cost_calculator/streamlit_app.py` | 8-tab dashboard (~2750 lines) |
| `tests/test_streamlit_calcs.py` | Unit tests for calculations |

## Config Pattern

```sql
MERGE INTO SFE_CONFIG USING (SELECT ... ) ON key = ...
WHEN MATCHED THEN UPDATE SET value = ...
WHEN NOT MATCHED THEN INSERT (key, value) VALUES (...);

SELECT GET_CONFIG('key_name');
```

## Extension Playbook: Adding a New Cortex Service View

1. Add the view to `sql/01_deployment/deploy_cortex_monitoring.sql`
2. Query the appropriate `ACCOUNT_USAGE` metering view
3. Include `service_type`, `credits_used`, `start_time` columns for compatibility
4. Add the view to the snapshot task's UNION ALL
5. Add a section in the Streamlit dashboard

## Extension Playbook: Exporting for Customer Proposals

1. Run `sql/02_utilities/export_metrics.sql` to export current metrics
2. Use the SE two-account workflow: export from customer account, import to SE account
3. The Streamlit "Export & Proposal" tab generates formatted cost projections
4. Persona calculator helps estimate costs for different user profiles

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.CORTEX_COST_CALCULATOR` |
| Warehouse | `SFE_CORTEX_COST_CALCULATOR_WH` |
| Views | 22 monitoring views |
| Table | `CORTEX_COST_SNAPSHOTS`, `SFE_CONFIG` |
| Task | Daily snapshot collection (serverless) |
| ML Model | ML.FORECAST for 12-month projections |
| Streamlit | Git-integrated dashboard |

## Gotchas

- ACCOUNT_USAGE views have 45min-3hr latency -- data is not real-time
- SSOT for expiration is line 7 of `deploy_all.sql`
- Streamlit uses `ADD LIVE VERSION FROM LAST` for Git-integrated updates
- ML.FORECAST requires minimum 2 data points; may fail on fresh accounts
- `COMMENT` required on all objects with expiration date
- Git-integrated deployment: Streamlit reads from Git repo, not inline code
- Unit tests in `tests/` cover calculation logic without Snowflake connection
