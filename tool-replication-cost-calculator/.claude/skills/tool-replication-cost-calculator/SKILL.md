---
name: tool-replication-cost-calculator
description: "DR replication cost estimator with Streamlit dashboard. Triggers: replication cost, DR cost calculator, failover cost, replication pricing, business critical pricing, cross-region replication, replication estimate."
---

# Replication Cost Calculator

## Purpose

Streamlit-in-Snowflake app for estimating Snowflake cross-region disaster recovery replication costs. Uses Business Critical pricing, auto-detects cloud/region, and provides interactive cost projections with admin-editable pricing.

## When to Use

- Estimating DR replication costs for a customer
- Updating pricing data for new regions or cloud providers
- Extending the calculator with new cost components

## Architecture

```
ACCOUNT_USAGE.TABLE_STORAGE_METRICS + DATABASES
       │
       ▼
DB_METADATA view (per-database storage)
       │
       ▼
PRICING_CURRENT table (AWS/Azure/GCP rates)
       │
       ▼
Streamlit App
  ├── Storage summary + region auto-detect
  ├── Database selector (multi-select)
  ├── Cost projection (monthly/annual)
  ├── Admin pricing editor
  └── CSV export
```

## Key Files

| File | Purpose |
|------|---------|
| `deploy_all.sql` | Schema, Git repo, pricing seed data, Streamlit from Git |
| `streamlit/app.py` | ~524-line calculator with pricing lookup, projections, admin editor |
| `sql/99_cleanup/99_drop_replication_calc.sql` | Full teardown including Git repo clone |

## Pricing Data Model

```sql
PRICING_CURRENT (
    cloud_provider VARCHAR,      -- 'AWS', 'AZURE', 'GCP'
    region VARCHAR,              -- e.g., 'us-west-2'
    storage_cost_per_tb FLOAT,   -- monthly $/TB
    data_transfer_cost FLOAT,    -- $/TB transferred
    effective_date DATE
)
```

## Extension Playbook: Adding a New Cloud Provider or Region

1. Add pricing rows to the seed data in `deploy_all.sql`
2. The Streamlit admin tab also allows live pricing edits
3. Cloud/region auto-detection uses `CURRENT_REGION()` -- new regions are handled by fallback pricing

## Extension Playbook: Adding a New Cost Component

1. Add the cost factor to `PRICING_CURRENT` as a new column (or separate table)
2. Add the calculation logic in `streamlit/app.py`
3. Include the component in the cost projection summary
4. Update the CSV export format

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.REPLICATION_CALC` |
| Warehouse | `SFE_REPLICATION_CALC_WH` |
| Table | `PRICING_CURRENT` |
| View | `DB_METADATA` |
| Streamlit | Git-integrated app |
| Git Repo | Clone of sfe-public |

## Gotchas

- ACCOUNTADMIN needed only for API integration (Git repo); SYSADMIN for everything else
- Pricing data is seeded at deploy time -- update for latest rates
- Cloud/region auto-detection has fallback pricing if exact match not found
- DB_METADATA uses ACCOUNT_USAGE views (latency applies)
- Git-integrated deployment: Streamlit reads `streamlit/app.py` from the Git repo
- Teardown drops the Git repo clone -- re-deployment requires fresh clone
