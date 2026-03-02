/*==============================================================================
05_DATA_QUALITY / 02_CUSTOM_DMFS
Custom Data Metric Functions for business rules and referential integrity.
Each DMF returns a NUMBER (count of violations) and is attached with an
EXPECTATION that defines the pass/fail threshold.

Patterns demonstrated:
  1. FK integrity check (multi-table argument)
  2. Positive amount validation
  3. Date sequence validation (due_date >= txn_date)

Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- 1. DMF_FK_CHECK: referential integrity between two tables
--    Counts rows in arg_t1 where arg_c1 has no matching arg_c2 in arg_t2.
-------------------------------------------------------------------------------
CREATE OR REPLACE DATA METRIC FUNCTION DMF_FK_CHECK(
    arg_t1 TABLE(arg_c1 VARCHAR),
    arg_t2 TABLE(arg_c2 VARCHAR)
)
RETURNS NUMBER
COMMENT = 'DEMO: Count orphan FK references (Expires: 2026-03-29)'
AS
$$
    SELECT COUNT(*)
    FROM arg_t1
    WHERE arg_c1 IS NOT NULL
      AND arg_c1 NOT IN (SELECT arg_c2 FROM arg_t2 WHERE arg_c2 IS NOT NULL)
$$;

-- Invoice customer_id must exist in STG_CUSTOMER
ALTER TABLE STG_INVOICE ADD DATA METRIC FUNCTION
    DMF_FK_CHECK ON (customer_id, TABLE STG_CUSTOMER(customer_id))
    EXPECTATION no_orphan_invoices (VALUE = 0);

-- Payment customer_id must exist in STG_CUSTOMER
ALTER TABLE STG_PAYMENT ADD DATA METRIC FUNCTION
    DMF_FK_CHECK ON (customer_id, TABLE STG_CUSTOMER(customer_id))
    EXPECTATION no_orphan_payments (VALUE = 0);

-- Bill vendor_id must exist in STG_VENDOR
ALTER TABLE STG_BILL ADD DATA METRIC FUNCTION
    DMF_FK_CHECK ON (vendor_id, TABLE STG_VENDOR(vendor_id))
    EXPECTATION no_orphan_bills (VALUE = 0);

-- Invoice line item_id must exist in STG_ITEM
ALTER TABLE STG_INVOICE_LINE ADD DATA METRIC FUNCTION
    DMF_FK_CHECK ON (item_id, TABLE STG_ITEM(item_id))
    EXPECTATION no_orphan_line_items (VALUE = 0);

ALTER TABLE STG_INVOICE_LINE SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';

-------------------------------------------------------------------------------
-- 2. DMF_POSITIVE_AMOUNT: business rule -- amounts must be positive
--    Counts rows where the amount column is zero or negative.
-------------------------------------------------------------------------------
CREATE OR REPLACE DATA METRIC FUNCTION DMF_POSITIVE_AMOUNT(
    arg_t TABLE(arg_c NUMBER)
)
RETURNS NUMBER
COMMENT = 'DEMO: Count non-positive amounts (Expires: 2026-03-29)'
AS
$$
    SELECT COUNT(*)
    FROM arg_t
    WHERE arg_c <= 0
$$;

-- Invoice total_amount must be positive
ALTER TABLE STG_INVOICE ADD DATA METRIC FUNCTION
    DMF_POSITIVE_AMOUNT ON (total_amount)
    EXPECTATION all_positive_invoice_amounts (VALUE = 0);

-- Payment total_amount must be positive
ALTER TABLE STG_PAYMENT ADD DATA METRIC FUNCTION
    DMF_POSITIVE_AMOUNT ON (total_amount)
    EXPECTATION all_positive_payment_amounts (VALUE = 0);

-- Bill total_amount must be positive
ALTER TABLE STG_BILL ADD DATA METRIC FUNCTION
    DMF_POSITIVE_AMOUNT ON (total_amount)
    EXPECTATION all_positive_bill_amounts (VALUE = 0);

-------------------------------------------------------------------------------
-- 3. DMF_DATE_SEQUENCE: business rule -- due_date must be >= txn_date
--    Counts rows where the date sequence is violated.
-------------------------------------------------------------------------------
CREATE OR REPLACE DATA METRIC FUNCTION DMF_DATE_SEQUENCE(
    arg_t TABLE(arg_txn DATE, arg_due DATE)
)
RETURNS NUMBER
COMMENT = 'DEMO: Count rows where due date precedes transaction date (Expires: 2026-03-29)'
AS
$$
    SELECT COUNT(*)
    FROM arg_t
    WHERE arg_due < arg_txn
$$;

-- Invoice due_date >= txn_date
ALTER TABLE STG_INVOICE ADD DATA METRIC FUNCTION
    DMF_DATE_SEQUENCE ON (txn_date, due_date)
    EXPECTATION valid_invoice_date_sequence (VALUE = 0);

-- Bill due_date >= txn_date
ALTER TABLE STG_BILL ADD DATA METRIC FUNCTION
    DMF_DATE_SEQUENCE ON (txn_date, due_date)
    EXPECTATION valid_bill_date_sequence (VALUE = 0);
