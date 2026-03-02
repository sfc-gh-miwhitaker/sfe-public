/*==============================================================================
04_GOLD / 02_CORTEX_INSIGHTS
Cortex AI-powered dynamic tables for business intelligence.
All run in incremental refresh mode -- Cortex processes only new rows.

Three patterns:
  1. CUSTOMER_CLASSIFICATION  -- AI_CLASSIFY with few-shot examples
  2. TRANSACTION_ANOMALIES    -- AI_COMPLETE structured output for anomaly reasoning
  3. PAYMENT_RISK             -- AI_COMPLETE structured output for late payment risk

Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- 1. CUSTOMER_CLASSIFICATION
--    AI_CLASSIFY with invoice/payment pattern context for customer health.
--    Uses a CTE to aggregate invoice stats, then classifies in the dynamic table.
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE CUSTOMER_CLASSIFICATION
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: AI-powered customer health classification (Expires: 2026-03-29)'
AS
WITH customer_invoice_agg AS (
    SELECT
        i.customer_id,
        COUNT(DISTINCT i.invoice_id)                              AS invoice_count,
        SUM(i.total_amount)                                       AS total_revenue,
        SUM(i.balance)                                            AS open_balance,
        MIN(i.txn_date)                                           AS first_invoice_date,
        MAX(i.txn_date)                                           AS last_invoice_date,
        AVG(DATEDIFF('day', i.txn_date, COALESCE(p.txn_date, CURRENT_DATE())))
                                                                  AS avg_days_to_pay
    FROM STG_INVOICE i
    LEFT JOIN STG_PAYMENT p ON i.customer_id = p.customer_id
    WHERE i.total_amount > 0
    GROUP BY i.customer_id
)
SELECT
    c.customer_id,
    c.display_name,
    c.company_name,
    agg.invoice_count,
    agg.total_revenue,
    agg.open_balance,
    agg.avg_days_to_pay,
    AI_CLASSIFY(
        CONCAT(
            'Customer: ', c.display_name,
            '. Total invoices: ', agg.invoice_count,
            '. Total revenue: $', agg.total_revenue,
            '. Open balance: $', agg.open_balance,
            '. Avg days to pay: ', ROUND(agg.avg_days_to_pay, 0),
            '. Last invoice: ', agg.last_invoice_date
        ),
        ['high-value', 'at-risk', 'growing', 'dormant'],
        {
            'task_description': 'Classify customer health based on invoice volume, revenue, payment speed, and recency',
            'examples': [
                {
                    'input': 'Customer: Acme Corp. Total invoices: 47. Total revenue: $284000. Open balance: $0. Avg days to pay: 12. Last invoice: 2026-02-15',
                    'labels': ['high-value'],
                    'explanation': 'High invoice count, high revenue, fast payment, recent activity'
                },
                {
                    'input': 'Customer: Stale Inc. Total invoices: 2. Total revenue: $3000. Open balance: $3000. Avg days to pay: 90. Last invoice: 2025-03-01',
                    'labels': ['at-risk', 'dormant'],
                    'explanation': 'Low volume, all outstanding, very slow payment, no recent activity'
                }
            ]
        }
    ):labels                                                      AS health_categories,
    c.fetched_at
FROM STG_CUSTOMER c
JOIN customer_invoice_agg agg ON c.customer_id = agg.customer_id;

-------------------------------------------------------------------------------
-- 2. TRANSACTION_ANOMALIES
--    AI_COMPLETE structured output to flag and explain invoice anomalies.
--    Returns a structured object with is_anomaly boolean and explanation.
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE TRANSACTION_ANOMALIES
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: AI-powered transaction anomaly detection (Expires: 2026-03-29)'
AS
SELECT
    i.invoice_id,
    i.doc_number,
    i.customer_id,
    c.display_name                                                AS customer_name,
    i.total_amount,
    i.balance,
    i.txn_date,
    i.due_date,
    AI_COMPLETE(
        'llama3.3-70b',
        CONCAT(
            'Analyze this invoice for anomalies. Consider: negative amounts, ',
            'due date before transaction date, unusually large amounts, missing customer. ',
            'Invoice: doc_number=', COALESCE(i.doc_number, 'NULL'),
            ', customer=', COALESCE(c.display_name, 'MISSING'),
            ', amount=$', i.total_amount,
            ', balance=$', i.balance,
            ', txn_date=', i.txn_date,
            ', due_date=', i.due_date
        ),
        response_format => TYPE OBJECT(
            is_anomaly  BOOLEAN COMMENT 'TRUE if any anomaly detected',
            severity    VARCHAR COMMENT 'low, medium, or high',
            reasons     ARRAY   COMMENT 'List of anomaly reasons found'
        )
    ):structured_output[0].raw_message                            AS anomaly_analysis,
    i.fetched_at
FROM STG_INVOICE i
LEFT JOIN STG_CUSTOMER c ON i.customer_id = c.customer_id;

-------------------------------------------------------------------------------
-- 3. PAYMENT_RISK
--    AI_COMPLETE structured output to score late payment likelihood.
--    Considers customer payment history, invoice age, and balance.
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE PAYMENT_RISK
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: AI-powered payment risk scoring (Expires: 2026-03-29)'
AS
WITH customer_pay_history AS (
    SELECT
        p.customer_id,
        COUNT(*)                                                  AS payment_count,
        AVG(p.total_amount)                                       AS avg_payment,
        MAX(p.txn_date)                                           AS last_payment_date
    FROM STG_PAYMENT p
    GROUP BY p.customer_id
)
SELECT
    i.invoice_id,
    i.doc_number,
    i.customer_id,
    c.display_name                                                AS customer_name,
    i.total_amount,
    i.balance,
    i.due_date,
    DATEDIFF('day', i.due_date, CURRENT_DATE())                   AS days_past_due,
    AI_COMPLETE(
        'llama3.3-70b',
        CONCAT(
            'Score the late payment risk for this outstanding invoice. ',
            'Invoice: amount=$', i.total_amount,
            ', balance=$', i.balance,
            ', due_date=', i.due_date,
            ', days_past_due=', DATEDIFF('day', i.due_date, CURRENT_DATE()),
            '. Customer payment history: ',
            COALESCE(ph.payment_count, 0), ' past payments',
            ', avg payment=$', COALESCE(ph.avg_payment, 0),
            ', last payment=', COALESCE(ph.last_payment_date::VARCHAR, 'never')
        ),
        response_format => TYPE OBJECT(
            risk_score     NUMBER  COMMENT 'Risk score 0-100 where 100 is highest risk',
            risk_level     VARCHAR COMMENT 'low, medium, or high',
            recommendation VARCHAR COMMENT 'Suggested action for collections'
        )
    ):structured_output[0].raw_message                            AS risk_assessment,
    i.fetched_at
FROM STG_INVOICE i
LEFT JOIN STG_CUSTOMER c ON i.customer_id = c.customer_id
LEFT JOIN customer_pay_history ph ON i.customer_id = ph.customer_id
WHERE i.balance > 0;
