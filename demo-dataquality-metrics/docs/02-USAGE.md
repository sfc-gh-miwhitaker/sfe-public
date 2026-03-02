# Usage Guide

## Initial State After Deployment

After running `deploy_all.sql`, the demo automatically:
1. Loads 60K sample records (10K athlete + 50K fan engagement)
2. Streams capture the initial data load
3. Task runs within 5 minutes and populates custom metrics
4. DMFs are configured with `TRIGGER_ON_CHANGES` (event-driven)

**Important Timing:**
- **Task metrics:** Available within 5 minutes (query `V_DATA_QUALITY_METRICS`)
- **Native DMF results:** Wait **10 minutes** for `TRIGGER_ON_CHANGES` to activate, then insert new data to trigger

> **Why 10 minutes?** Snowflake requires ~10 minutes for a new DMF schedule to become effective. After activation, any INSERT/UPDATE/DELETE immediately triggers DMF execution.

## View Data Quality Metrics

```sql
SELECT
  metric_date,
  table_name,
  metric_name,
  metric_value,
  records_evaluated,
  failures_detected
FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_DATA_QUALITY_METRICS
ORDER BY metric_date DESC, table_name, metric_name;
```

## View Quality Trends

```sql
SELECT
  metric_date,
  table_name,
  avg_quality_score
FROM SNOWFLAKE_EXAMPLE.DATA_QUALITY.V_QUALITY_SCORE_TREND
ORDER BY metric_date DESC, table_name;
```

## Demonstrate Live Data Quality Updates

To show the demo processing new data in real-time, use the sample data script:

**Option 1: Run the helper script**
```sql
-- Copy and run tools/insert_sample_data.sql in Snowsight
-- This inserts 300 records with intentional quality issues
```

**Option 2: Insert a single record manually**
```sql
INSERT INTO SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE (
  athlete_id, ngb_code, sport, event_date, metric_type, metric_value, data_source, load_timestamp
)
VALUES ('A-DEMO01', 'USA', 'Track', CURRENT_DATE(), 'speed', 120.0, 'live_demo', CURRENT_TIMESTAMP());
```

**Option 3: Force immediate task execution**
```sql
-- Don't wait 5 minutes - run the task now
EXECUTE TASK SNOWFLAKE_EXAMPLE.DATA_QUALITY.refresh_data_quality_metrics_task;
```

## Check Stream Status

Verify streams have captured new data:

```sql
SELECT
  'RAW_ATHLETE_PERFORMANCE_STREAM' AS stream_name,
  SYSTEM$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE_STREAM') AS has_data
UNION ALL
SELECT
  'RAW_FAN_ENGAGEMENT_STREAM',
  SYSTEM$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_FAN_ENGAGEMENT_STREAM');
```

## View Native DMF Results

Data Metric Functions store results in Snowflake's event table. Two ways to query:

**Option 1: Table function (single table)**
```sql
SELECT *
FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS(
  REF_ENTITY_NAME => 'SNOWFLAKE_EXAMPLE.DATA_QUALITY.RAW_ATHLETE_PERFORMANCE',
  REF_ENTITY_DOMAIN => 'TABLE'
))
ORDER BY MEASUREMENT_TIME DESC
LIMIT 10;
```

**Option 2: View (all tables)**
```sql
SELECT TABLE_NAME, METRIC_NAME, VALUE, MEASUREMENT_TIME
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE TABLE_DATABASE = 'SNOWFLAKE_EXAMPLE'
ORDER BY MEASUREMENT_TIME DESC
LIMIT 20;
```

**Option 3: Native UI (no SQL)**
- Catalog → Database Explorer → Select table → **Data Quality** tab

## Streamlit Dashboard

1. In Snowsight, navigate to **Projects → Streamlit**.
2. Open the app named `DATA_QUALITY_DASHBOARD`.
3. Use the sidebar filters to explore quality scores by table and metric.
4. The dashboard shows the last 30 days of quality trends.

## Demo Flow Summary

| Step | What Happens | Timing |
|------|--------------|--------|
| Deploy | Sample data loaded, streams capture INSERTs | Immediate |
| Wait | Task processes stream data | Within 5 min |
| View | Dashboard shows quality metrics | After task runs |
| Insert | Add new data to show live updates | Manual trigger |
| Refresh | Task processes new stream data | Within 5 min (or use EXECUTE TASK) |
