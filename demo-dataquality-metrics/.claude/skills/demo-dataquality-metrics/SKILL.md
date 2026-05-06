---
name: demo-dataquality-metrics
description: "Automated data quality monitoring with Data Metric Functions and Streamlit reporting. Triggers: data quality, DMF, data metric function, TRIGGER_ON_CHANGES, quality metrics, quality dashboard, quality trends, athlete performance, fan engagement, custom DMF."
---

# Data Quality Metrics & Reporting

## Purpose

Automated data quality monitoring using Snowflake Data Metric Functions (system + custom), streams for change detection, a task for metric computation, and a Streamlit dashboard with real-time quality scoring, trend analysis, and a system DMF reference.

## When to Use

- Adding new quality checks or custom DMFs
- Extending the Streamlit quality dashboard
- Working with streams + tasks for incremental quality computation
- Adapting the pattern for different datasets

## Architecture

```
RAW_ATHLETE_PERFORMANCE (10K rows)    RAW_FAN_ENGAGEMENT (50K rows)
  │ intentional quality issues           │ intentional quality issues
  ▼                                      ▼
Streams (change capture)             Streams (change capture)
  │                                      │
  └──────────┬───────────────────────────┘
             ▼
Task (5-minute schedule) → STG_DATA_QUALITY_METRICS
             │
             ▼
Quality Views (V_ATHLETE_PERFORMANCE, V_FAN_ENGAGEMENT)
Custom DMFs (value validity, session duration)
System DMFs (NULL_COUNT, UNIQUE_COUNT, FRESHNESS, etc.)
             │
             ▼
Streamlit Dashboard (4 tabs)
  ├── Real-Time Quality (live DMF calls)
  ├── Quality Trends (historical metrics)
  ├── Dataset Explorer (filtered data)
  └── System DMF Reference
```

## Key Files

| File | Purpose |
|------|---------|
| `sql/02_data/01_create_tables.sql` | 3 TRANSIENT tables |
| `sql/02_data/02_load_sample_data.sql` | 10K athlete + 50K fan records with DQ issues |
| `sql/03_transformations/01_create_streams.sql` | Change capture streams |
| `sql/03_transformations/02_create_views.sql` | Custom DMFs, EXPECTATIONS, golden views, metrics views |
| `sql/03_transformations/03_create_tasks.sql` | 5-minute quality computation task |
| `streamlit/streamlit_app.py` | 4-tab quality dashboard |
| `tools/DEMO_SCRIPT.sql` | 5-part interactive demo walkthrough |
| `tools/insert_sample_data.sql` | Additional data for live demos |

## Custom DMF Pattern

```sql
CREATE OR REPLACE DATA METRIC FUNCTION DMF_<NAME>(ARG_T TABLE(<col> <type>))
RETURNS NUMBER AS
'SELECT COUNT_IF(<condition>) FROM ARG_T';

ALTER TABLE <table> SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE <table> ADD DATA METRIC FUNCTION DMF_<NAME> ON (<col>);
```

Custom DMFs in this project:
- `DMF_METRIC_VALUE_VALID_PCT` -- validates metric values are within expected ranges
- `DMF_SESSION_DURATION_VALID_PCT` -- validates session durations are positive and reasonable

## Extension Playbook: Adding a New Quality Check

1. Define a new custom DMF in `sql/03_transformations/02_create_views.sql`
2. Attach it to the target table with `ALTER TABLE ... ADD DATA METRIC FUNCTION`
3. Set the schedule: `ALTER TABLE ... SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES'`
4. Add expectations if appropriate: `ALTER TABLE ... ALTER COLUMN ... SET METRIC EXPECTATIONS`
5. Update the Streamlit dashboard to display the new metric
6. Add a step in `tools/DEMO_SCRIPT.sql` for live walkthrough

## Extension Playbook: Adding a New Dataset

1. Create the TRANSIENT table in `sql/02_data/01_create_tables.sql`
2. Load sample data with intentional quality issues in `sql/02_data/02_load_sample_data.sql`
3. Create a stream in `sql/03_transformations/01_create_streams.sql`
4. Add the stream read + metric INSERT to the task in `03_create_tasks.sql`
5. Attach system DMFs (NULL_COUNT, UNIQUE_COUNT, FRESHNESS) via ALTER TABLE
6. Create custom DMFs for domain-specific validation
7. Add a golden view with QUALIFY dedup and data cleansing

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.DATA_QUALITY` |
| Warehouse | `SFE_DATA_QUALITY_WH` |
| Tables | `RAW_ATHLETE_PERFORMANCE`, `RAW_FAN_ENGAGEMENT`, `STG_DATA_QUALITY_METRICS` |
| Streams | On both RAW tables |
| Task | 5-minute quality metric computation |
| Views | `V_ATHLETE_PERFORMANCE`, `V_FAN_ENGAGEMENT`, metrics views |
| Custom DMFs | `DMF_METRIC_VALUE_VALID_PCT`, `DMF_SESSION_DURATION_VALID_PCT` |
| Streamlit | In-schema dashboard |

## Gotchas

- Tables are TRANSIENT (no Time Travel or Fail-Safe) to reduce demo costs
- `TRIGGER_ON_CHANGES` fires on DML, not on schedule -- insert data to trigger DMFs
- System DMFs have a built-in evaluation window; results may lag a few minutes
- The task reads from streams, so it processes only net-new changes
- `tools/DEMO_SCRIPT.sql` is interactive -- designed for live presentation, not automation
- Git-integrated deployment: `EXECUTE IMMEDIATE FROM` references files in the Git repo
