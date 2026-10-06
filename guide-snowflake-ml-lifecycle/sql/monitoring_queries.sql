/*
  Snowflake ML Lifecycle — model monitor, metric queries, and a threshold alert
  Pair-programmed by SE Community + Cortex Code

  Assumes a registered binary classifier ML_DB.ML.CHURN_MODEL version V1, logged with
  task=TABULAR_BINARY_CLASSIFICATION, and an inference log table the batch job appends to.
  Substitute names in the ALERT action (notification integration, email).
*/

USE SCHEMA ML_DB.ML;

-- 1. Inference log the monitor reads. TIMESTAMP_COLUMN must be TIMESTAMP_NTZ.
CREATE TABLE IF NOT EXISTS ML_DB.ML.CHURN_INFERENCE_LOG (
    customer_id      VARCHAR,
    scored_at        TIMESTAMP_NTZ,
    tenure_months    NUMBER,
    monthly_charges  FLOAT,
    support_tickets  NUMBER,
    region           VARCHAR,
    predicted_score  FLOAT,
    predicted_class  NUMBER,
    actual_class     NUMBER            -- backfilled when the label arrives
);

-- Baseline = the scored validation set. The monitor copies a SNAPSHOT of this table at
-- CREATE time, so it must be populated first; an empty baseline means no drift, ever,
-- and fixing it means recreating the monitor. Load it from your validation scoring run.
CREATE TABLE IF NOT EXISTS ML_DB.ML.CHURN_BASELINE LIKE ML_DB.ML.CHURN_INFERENCE_LOG;
-- INSERT INTO ML_DB.ML.CHURN_BASELINE (...) SELECT ... FROM <scored validation set>;
-- Stop here until SELECT COUNT(*) FROM ML_DB.ML.CHURN_BASELINE returns > 0.

-- 2. Model version monitor (one per model version; refresh runs on ML_WH and bills there)
CREATE MODEL MONITOR IF NOT EXISTS ML_DB.ML.CHURN_MODEL_V1_MONITOR
WITH
    MODEL = ML_DB.ML.CHURN_MODEL
    VERSION = 'V1'
    FUNCTION = 'predict_proba'
    SOURCE = ML_DB.ML.CHURN_INFERENCE_LOG
    BASELINE = ML_DB.ML.CHURN_BASELINE
    WAREHOUSE = ML_WH
    REFRESH_INTERVAL = '1 hour'
    AGGREGATION_WINDOW = '1 day'
    TIMESTAMP_COLUMN = scored_at
    ID_COLUMNS = ('CUSTOMER_ID')
    PREDICTION_SCORE_COLUMNS = ('PREDICTED_SCORE')
    PREDICTION_CLASS_COLUMNS = ('PREDICTED_CLASS')
    ACTUAL_CLASS_COLUMNS = ('ACTUAL_CLASS')
    SEGMENT_COLUMNS = ('REGION');

-- 3. Drift on one feature, daily, last 30 days
SELECT event_timestamp, metric_name, column_name, metric_value
FROM TABLE(MODEL_MONITOR_DRIFT_METRIC(
    'ML_DB.ML.CHURN_MODEL_V1_MONITOR', 'JENSEN_SHANNON', 'MONTHLY_CHARGES',
    '1 DAY', DATEADD('day', -30, CURRENT_TIMESTAMP())::TIMESTAMP_NTZ, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ));

-- 4. Performance, daily
SELECT event_timestamp, metric_name, metric_value
FROM TABLE(MODEL_MONITOR_PERFORMANCE_METRIC(
    'ML_DB.ML.CHURN_MODEL_V1_MONITOR', 'ROC_AUC',
    '1 DAY', DATEADD('day', -30, CURRENT_TIMESTAMP())::TIMESTAMP_NTZ, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ));

-- 5. Volume and nulls on the score column (catches a silently broken upstream)
SELECT event_timestamp, metric_name, column_name, metric_value
FROM TABLE(MODEL_MONITOR_STAT_METRIC(
    'ML_DB.ML.CHURN_MODEL_V1_MONITOR', 'COUNT_NULL', 'PREDICTED_SCORE',
    '1 DAY', DATEADD('day', -7, CURRENT_TIMESTAMP())::TIMESTAMP_NTZ, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ));

-- 6. Custom metric table for anything the monitor doesn't compute (business KPIs, latency
--    from inference logs). A Streamlit app or dashboard reads this table.
CREATE TABLE IF NOT EXISTS ML_DB.ML.CUSTOM_MODEL_METRICS (
    metric_date   DATE,
    model_name    VARCHAR,
    version_name  VARCHAR,
    metric_name   VARCHAR,
    metric_value  FLOAT
);

-- 7. Threshold alert. Alerts are created SUSPENDED; resume explicitly.
--    CREATE ALERT does not validate the condition SQL — test the SELECT first.
CREATE ALERT IF NOT EXISTS ML_DB.ML.CHURN_DRIFT_ALERT
    WAREHOUSE = ML_WH
    SCHEDULE = 'USING CRON 0 7 * * * UTC'
    IF (EXISTS (
        -- Last COMPLETE daily bucket only; today's partial bucket understates drift.
        SELECT metric_value
        FROM TABLE(MODEL_MONITOR_DRIFT_METRIC(
            'ML_DB.ML.CHURN_MODEL_V1_MONITOR', 'JENSEN_SHANNON', 'MONTHLY_CHARGES',
            '1 DAY', DATEADD('day', -3, CURRENT_DATE())::TIMESTAMP_NTZ, CURRENT_DATE()::TIMESTAMP_NTZ))
        QUALIFY ROW_NUMBER() OVER (ORDER BY event_timestamp DESC) = 1
            AND metric_value > 0.2
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'ML_EMAIL_INT',
            'ml-oncall@example.com',
            'CHURN_MODEL V1 drift above 0.2',
            'MONTHLY_CHARGES Jensen-Shannon drift exceeded threshold. Check the monitor dashboard (AI & ML > Models).');

ALTER ALERT ML_DB.ML.CHURN_DRIFT_ALERT RESUME;
