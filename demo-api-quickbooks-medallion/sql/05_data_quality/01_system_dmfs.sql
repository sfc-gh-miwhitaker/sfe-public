/*==============================================================================
05_DATA_QUALITY / 01_SYSTEM_DMFS
System Data Metric Functions attached to Silver dynamic tables.
Features demonstrated:
  - EXPECTATIONS: Boolean pass/fail thresholds (VALUE = 0, VALUE > 0)
  - ANOMALY_DETECTION: ML-powered for FRESHNESS and ROW_COUNT
  - CRON scheduling: hourly evaluation on serverless compute

DMFs run on serverless compute -- no warehouse cost for scheduled evaluations.
Results flow to SNOWFLAKE.LOCAL event table views.
Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- STG_INVOICE: primary target for comprehensive DQ monitoring
-------------------------------------------------------------------------------

-- NULL_COUNT: customer_id must never be null
ALTER TABLE STG_INVOICE ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (customer_id)
    EXPECTATION no_null_customers (VALUE = 0);

-- NULL_COUNT: total_amount must never be null
ALTER TABLE STG_INVOICE ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (total_amount)
    EXPECTATION no_null_amounts (VALUE = 0);

-- DUPLICATE_COUNT: invoice_id must be unique
ALTER TABLE STG_INVOICE ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.DUPLICATE_COUNT ON (invoice_id)
    EXPECTATION no_duplicate_invoices (VALUE = 0);

-- FRESHNESS: ML anomaly detection on data staleness
ALTER TABLE STG_INVOICE ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.FRESHNESS ON (fetched_at)
    ANOMALY_DETECTION = TRUE;

-- ROW_COUNT: ensure table is not empty + anomaly detection for volume shifts
ALTER TABLE STG_INVOICE ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.ROW_COUNT ON ()
    EXPECTATION min_row_count (VALUE > 0)
    ANOMALY_DETECTION = TRUE;

-- Schedule: evaluate every hour
ALTER TABLE STG_INVOICE SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';

-------------------------------------------------------------------------------
-- STG_CUSTOMER: dimension integrity
-------------------------------------------------------------------------------

ALTER TABLE STG_CUSTOMER ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (customer_id)
    EXPECTATION no_null_customer_ids (VALUE = 0);

ALTER TABLE STG_CUSTOMER ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (display_name)
    EXPECTATION no_null_display_names (VALUE = 0);

ALTER TABLE STG_CUSTOMER ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.DUPLICATE_COUNT ON (customer_id)
    EXPECTATION no_duplicate_customers (VALUE = 0);

ALTER TABLE STG_CUSTOMER ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.ROW_COUNT ON ()
    EXPECTATION has_customers (VALUE > 0)
    ANOMALY_DETECTION = TRUE;

ALTER TABLE STG_CUSTOMER SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';

-------------------------------------------------------------------------------
-- STG_VENDOR: dimension integrity
-------------------------------------------------------------------------------

ALTER TABLE STG_VENDOR ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (vendor_id)
    EXPECTATION no_null_vendor_ids (VALUE = 0);

ALTER TABLE STG_VENDOR ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.DUPLICATE_COUNT ON (vendor_id)
    EXPECTATION no_duplicate_vendors (VALUE = 0);

ALTER TABLE STG_VENDOR SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';

-------------------------------------------------------------------------------
-- STG_PAYMENT: transaction integrity
-------------------------------------------------------------------------------

ALTER TABLE STG_PAYMENT ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (customer_id)
    EXPECTATION no_null_payment_customers (VALUE = 0);

ALTER TABLE STG_PAYMENT ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (total_amount)
    EXPECTATION no_null_payment_amounts (VALUE = 0);

ALTER TABLE STG_PAYMENT ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.DUPLICATE_COUNT ON (payment_id)
    EXPECTATION no_duplicate_payments (VALUE = 0);

ALTER TABLE STG_PAYMENT SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';

-------------------------------------------------------------------------------
-- STG_BILL: transaction integrity
-------------------------------------------------------------------------------

ALTER TABLE STG_BILL ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (vendor_id)
    EXPECTATION no_null_bill_vendors (VALUE = 0);

ALTER TABLE STG_BILL ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.DUPLICATE_COUNT ON (bill_id)
    EXPECTATION no_duplicate_bills (VALUE = 0);

ALTER TABLE STG_BILL ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.FRESHNESS ON (fetched_at)
    ANOMALY_DETECTION = TRUE;

ALTER TABLE STG_BILL SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';

-------------------------------------------------------------------------------
-- STG_ITEM: product catalog integrity
-------------------------------------------------------------------------------

ALTER TABLE STG_ITEM ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (item_id)
    EXPECTATION no_null_item_ids (VALUE = 0);

ALTER TABLE STG_ITEM ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.DUPLICATE_COUNT ON (item_id)
    EXPECTATION no_duplicate_items (VALUE = 0);

ALTER TABLE STG_ITEM SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';

-------------------------------------------------------------------------------
-- STG_ACCOUNT: chart of accounts integrity
-------------------------------------------------------------------------------

ALTER TABLE STG_ACCOUNT ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (account_id)
    EXPECTATION no_null_account_ids (VALUE = 0);

ALTER TABLE STG_ACCOUNT ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.DUPLICATE_COUNT ON (account_id)
    EXPECTATION no_duplicate_accounts (VALUE = 0);

ALTER TABLE STG_ACCOUNT SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';
