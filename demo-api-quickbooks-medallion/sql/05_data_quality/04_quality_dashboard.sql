/*==============================================================================
05_DATA_QUALITY / 04_QUALITY_DASHBOARD
Queries for monitoring DQ expectation violations, anomaly detection status,
raw DMF results, and remediation via SYSTEM$DATA_METRIC_SCAN.

Run these interactively after sample data is loaded and DMFs have evaluated.
For the Cortex Data Quality (AI-suggested checks) walkthrough, see
docs/03-ARCHITECTURE.md.

Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

/*-----------------------------------------------------------------------------
 1. EXPECTATION VIOLATIONS
    Which expectations are currently failing? The sample data intentionally
    includes issues that will show up here:
    - no_null_customers: INV-007 has NULL customer_id
    - no_duplicate_invoices: INV-003 appears twice
    - all_positive_invoice_amounts: INV-008 has a negative amount
    - valid_invoice_date_sequence: INV-009 has due_date < txn_date
    - no_orphan_invoices: INV-010 references customer_id = 99 (not in STG_CUSTOMER)
-----------------------------------------------------------------------------*/
SELECT *
FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
    REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_INVOICE',
    REF_ENTITY_DOMAIN => 'TABLE'
));

-- Cross-table expectation summary: all Silver tables at once
SELECT *
FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
    REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_CUSTOMER',
    REF_ENTITY_DOMAIN => 'TABLE'
))
UNION ALL
SELECT *
FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
    REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_VENDOR',
    REF_ENTITY_DOMAIN => 'TABLE'
))
UNION ALL
SELECT *
FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
    REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_PAYMENT',
    REF_ENTITY_DOMAIN => 'TABLE'
))
UNION ALL
SELECT *
FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
    REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_BILL',
    REF_ENTITY_DOMAIN => 'TABLE'
));

/*-----------------------------------------------------------------------------
 2. ANOMALY DETECTION STATUS
    ML-powered anomaly detection for FRESHNESS and ROW_COUNT.
    Shows whether current values are within the predicted range based on
    historical patterns. Useful for catching unexpected volume drops or
    data pipeline stalls.
-----------------------------------------------------------------------------*/
SELECT *
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_ANOMALY_DETECTION_STATUS;

/*-----------------------------------------------------------------------------
 3. RAW DMF RESULTS OVER TIME
    Historical metric values for trend analysis.
    Shows when each DMF ran, what it measured, and the result.
-----------------------------------------------------------------------------*/
SELECT
    scheduled_time,
    measurement_time,
    metric_name,
    metric_schema,
    ref_entity_name,
    arguments_names,
    value,
    expectation_name,
    expectation_result
FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS(
    REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_INVOICE',
    REF_ENTITY_DOMAIN => 'TABLE'
))
ORDER BY scheduled_time DESC;

/*-----------------------------------------------------------------------------
 4. REMEDIATION: Drill into Failing Rows
    SYSTEM$DATA_METRIC_SCAN returns the actual rows that caused a DMF to fail.
    Use this to quickly identify and fix data quality issues.
-----------------------------------------------------------------------------*/

-- Which invoices have NULL customer_id?
SELECT *
FROM TABLE(SYSTEM$DATA_METRIC_SCAN(
    REF_ENTITY_NAME => 'SNOWFLAKE_EXAMPLE.QB_API.STG_INVOICE',
    METRIC_NAME     => 'SNOWFLAKE.CORE.NULL_COUNT',
    ARGUMENT_NAME   => 'CUSTOMER_ID'
));

-- Which invoices are duplicates?
SELECT *
FROM TABLE(SYSTEM$DATA_METRIC_SCAN(
    REF_ENTITY_NAME => 'SNOWFLAKE_EXAMPLE.QB_API.STG_INVOICE',
    METRIC_NAME     => 'SNOWFLAKE.CORE.DUPLICATE_COUNT',
    ARGUMENT_NAME   => 'INVOICE_ID'
));

/*-----------------------------------------------------------------------------
 5. ON-DEMAND EXPECTATION EVALUATION
    Test all expectations immediately without waiting for the cron schedule.
    Useful during development and after loading new data.
-----------------------------------------------------------------------------*/
SELECT *
FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(
    REF_ENTITY_NAME => 'SNOWFLAKE_EXAMPLE.QB_API.STG_INVOICE'
));

/*-----------------------------------------------------------------------------
 6. DQ SUMMARY VIEW (create for dashboarding)
    A convenience view that aggregates the latest expectation results
    across all monitored Silver tables into a single pane.
-----------------------------------------------------------------------------*/
CREATE OR REPLACE VIEW DQ_EXPECTATION_SUMMARY
    COMMENT = 'DEMO: Aggregated DQ expectation status across Silver tables (Expires: 2026-03-29)'
AS
WITH invoice_status AS (
    SELECT * FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
        REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_INVOICE',
        REF_ENTITY_DOMAIN => 'TABLE'))
),
customer_status AS (
    SELECT * FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
        REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_CUSTOMER',
        REF_ENTITY_DOMAIN => 'TABLE'))
),
vendor_status AS (
    SELECT * FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
        REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_VENDOR',
        REF_ENTITY_DOMAIN => 'TABLE'))
),
payment_status AS (
    SELECT * FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
        REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_PAYMENT',
        REF_ENTITY_DOMAIN => 'TABLE'))
),
bill_status AS (
    SELECT * FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
        REF_ENTITY_NAME  => 'SNOWFLAKE_EXAMPLE.QB_API.STG_BILL',
        REF_ENTITY_DOMAIN => 'TABLE'))
)
SELECT * FROM invoice_status
UNION ALL SELECT * FROM customer_status
UNION ALL SELECT * FROM vendor_status
UNION ALL SELECT * FROM payment_status
UNION ALL SELECT * FROM bill_status;
