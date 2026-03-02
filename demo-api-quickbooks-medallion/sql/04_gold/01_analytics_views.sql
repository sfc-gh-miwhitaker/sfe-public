/*==============================================================================
04_GOLD / 01_ANALYTICS_VIEWS
Business-ready analytics views built on Silver dynamic tables.
These are standard SQL views (no Cortex) -- fast, deterministic, zero AI cost.
Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- AR_AGING: Outstanding invoices bucketed by days past due
-------------------------------------------------------------------------------
CREATE OR REPLACE VIEW AR_AGING
    COMMENT = 'DEMO: Accounts receivable aging buckets (Expires: 2026-03-29)'
AS
SELECT
    i.invoice_id,
    i.doc_number,
    i.customer_id,
    c.display_name                                                AS customer_name,
    i.txn_date,
    i.due_date,
    i.total_amount,
    i.balance,
    DATEDIFF('day', i.due_date, CURRENT_DATE())                   AS days_past_due,
    CASE
        WHEN i.balance = 0                                        THEN 'Paid'
        WHEN DATEDIFF('day', i.due_date, CURRENT_DATE()) <= 0    THEN 'Current'
        WHEN DATEDIFF('day', i.due_date, CURRENT_DATE()) <= 30   THEN '1-30 Days'
        WHEN DATEDIFF('day', i.due_date, CURRENT_DATE()) <= 60   THEN '31-60 Days'
        WHEN DATEDIFF('day', i.due_date, CURRENT_DATE()) <= 90   THEN '61-90 Days'
        ELSE '90+ Days'
    END                                                            AS aging_bucket
FROM STG_INVOICE i
LEFT JOIN STG_CUSTOMER c ON i.customer_id = c.customer_id;

-------------------------------------------------------------------------------
-- REVENUE_BY_MONTH: Monthly revenue trend from invoices
-------------------------------------------------------------------------------
CREATE OR REPLACE VIEW REVENUE_BY_MONTH
    COMMENT = 'DEMO: Monthly revenue from invoices (Expires: 2026-03-29)'
AS
SELECT
    DATE_TRUNC('month', i.txn_date)                               AS revenue_month,
    COUNT(DISTINCT i.invoice_id)                                  AS invoice_count,
    SUM(i.total_amount)                                           AS total_revenue,
    SUM(i.total_amount - i.balance)                               AS collected_revenue,
    SUM(i.balance)                                                AS outstanding_balance,
    COUNT(DISTINCT i.customer_id)                                 AS unique_customers
FROM STG_INVOICE i
WHERE i.total_amount > 0
GROUP BY DATE_TRUNC('month', i.txn_date)
ORDER BY revenue_month;

-------------------------------------------------------------------------------
-- VENDOR_SPEND: Spend by vendor from bills
-------------------------------------------------------------------------------
CREATE OR REPLACE VIEW VENDOR_SPEND
    COMMENT = 'DEMO: Spend by vendor from bills (Expires: 2026-03-29)'
AS
SELECT
    b.vendor_id,
    v.display_name                                                AS vendor_name,
    v.company_name                                                AS vendor_company,
    COUNT(DISTINCT b.bill_id)                                     AS bill_count,
    SUM(b.total_amount)                                           AS total_spend,
    SUM(b.balance)                                                AS unpaid_balance,
    MIN(b.txn_date)                                               AS first_bill_date,
    MAX(b.txn_date)                                               AS last_bill_date
FROM STG_BILL b
LEFT JOIN STG_VENDOR v ON b.vendor_id = v.vendor_id
GROUP BY b.vendor_id, v.display_name, v.company_name
ORDER BY total_spend DESC;

-------------------------------------------------------------------------------
-- CASH_FLOW_SUMMARY: Payments received vs bills owed over time
-------------------------------------------------------------------------------
CREATE OR REPLACE VIEW CASH_FLOW_SUMMARY
    COMMENT = 'DEMO: Cash flow - payments received vs bills due (Expires: 2026-03-29)'
AS
WITH inflows AS (
    SELECT
        DATE_TRUNC('month', txn_date)   AS flow_month,
        SUM(total_amount)               AS amount
    FROM STG_PAYMENT
    GROUP BY DATE_TRUNC('month', txn_date)
),
outflows AS (
    SELECT
        DATE_TRUNC('month', txn_date)   AS flow_month,
        SUM(total_amount)               AS amount
    FROM STG_BILL
    GROUP BY DATE_TRUNC('month', txn_date)
)
SELECT
    COALESCE(i.flow_month, o.flow_month)                          AS flow_month,
    COALESCE(i.amount, 0)                                         AS payments_received,
    COALESCE(o.amount, 0)                                         AS bills_due,
    COALESCE(i.amount, 0) - COALESCE(o.amount, 0)                AS net_cash_flow
FROM inflows i
FULL OUTER JOIN outflows o ON i.flow_month = o.flow_month
ORDER BY flow_month;

-------------------------------------------------------------------------------
-- CUSTOMER_LIFETIME_VALUE: Revenue and payment patterns per customer
-------------------------------------------------------------------------------
CREATE OR REPLACE VIEW CUSTOMER_LIFETIME_VALUE
    COMMENT = 'DEMO: Customer lifetime value metrics (Expires: 2026-03-29)'
AS
WITH invoice_stats AS (
    SELECT
        customer_id,
        COUNT(DISTINCT invoice_id)                                AS invoice_count,
        SUM(total_amount)                                         AS total_invoiced,
        SUM(balance)                                              AS total_outstanding,
        MIN(txn_date)                                             AS first_invoice_date,
        MAX(txn_date)                                             AS last_invoice_date,
        AVG(total_amount)                                         AS avg_invoice_amount
    FROM STG_INVOICE
    WHERE total_amount > 0
    GROUP BY customer_id
),
payment_stats AS (
    SELECT
        customer_id,
        COUNT(DISTINCT payment_id)                                AS payment_count,
        SUM(total_amount)                                         AS total_paid
    FROM STG_PAYMENT
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.display_name,
    c.company_name,
    c.email,
    COALESCE(inv.invoice_count, 0)                                AS invoice_count,
    COALESCE(inv.total_invoiced, 0)                               AS total_invoiced,
    COALESCE(inv.total_outstanding, 0)                            AS total_outstanding,
    COALESCE(pay.total_paid, 0)                                   AS total_paid,
    inv.first_invoice_date,
    inv.last_invoice_date,
    inv.avg_invoice_amount,
    DATEDIFF('day', inv.first_invoice_date, inv.last_invoice_date) AS customer_tenure_days,
    CASE
        WHEN pay.total_paid > 0 AND inv.total_invoiced > 0
        THEN ROUND(pay.total_paid / inv.total_invoiced * 100, 1)
        ELSE 0
    END                                                            AS collection_rate_pct
FROM STG_CUSTOMER c
LEFT JOIN invoice_stats inv ON c.customer_id = inv.customer_id
LEFT JOIN payment_stats pay ON c.customer_id = pay.customer_id
ORDER BY total_invoiced DESC;
