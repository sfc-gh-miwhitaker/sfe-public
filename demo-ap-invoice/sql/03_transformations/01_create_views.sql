/*==============================================================================
VIEWS - AP Invoice Pipeline
Analytical views joining header, lines, vendors, and audit data.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-08
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.AP_INVOICE;

-- Core analytics view: fully resolved invoices with vendor and line item details
CREATE OR REPLACE VIEW PROCESSED_INVOICES
  COMMENT = 'DEMO: Joined invoice data for analytics and export (Expires: 2026-05-08)'
AS
SELECT
    h.INVOICE_ID,
    h.SOURCE_FILE,
    h.INVOICE_NUMBER,
    h.INVOICE_DATE,
    h.PO_REFERENCE,
    h.TOTAL_AMOUNT,
    h.CURRENCY,
    h.PROPERTY,
    h.VALIDATION_SCORE,
    h.STATUS,
    h.EXTRACTION_TS,
    h.APPROVED_BY,
    h.APPROVED_TS,
    DATEDIFF('second', h.EXTRACTION_TS, COALESCE(h.APPROVED_TS, CURRENT_TIMESTAMP())) AS PROCESSING_SECONDS,
    h.VENDOR_NAME_RAW,
    v.VENDOR_NAME      AS VENDOR_NAME_RESOLVED,
    v.VENDOR_ID        AS VENDOR_ID,
    v.PAYMENT_TERMS,
    li.LINE_COUNT,
    li.LINE_TOTAL_SUM
FROM INVOICE_HEADER h
LEFT JOIN VENDOR_MASTER v
    ON h.VENDOR_ID_RESOLVED = v.VENDOR_ID
LEFT JOIN (
    SELECT
        INVOICE_ID,
        COUNT(*)         AS LINE_COUNT,
        SUM(LINE_TOTAL)  AS LINE_TOTAL_SUM
    FROM INVOICE_LINE_ITEMS
    GROUP BY INVOICE_ID
) li
    ON h.INVOICE_ID = li.INVOICE_ID;

-- Review queue view with vendor context
CREATE OR REPLACE VIEW V_REVIEW_QUEUE
  COMMENT = 'DEMO: Pending review items with invoice context (Expires: 2026-05-08)'
AS
SELECT
    rq.QUEUE_ID,
    rq.INVOICE_ID,
    h.SOURCE_FILE,
    h.VENDOR_NAME_RAW,
    h.INVOICE_NUMBER,
    h.INVOICE_DATE,
    h.TOTAL_AMOUNT,
    h.PROPERTY,
    rq.FLAGGED_FIELDS,
    rq.VALIDATION_SCORE,
    rq.REVIEWER_ID,
    rq.REVIEWED_TS,
    rq.RESOLUTION,
    rq.NOTES
FROM REVIEW_QUEUE rq
JOIN INVOICE_HEADER h
    ON rq.INVOICE_ID = h.INVOICE_ID;

-- Line items with GL code details
CREATE OR REPLACE VIEW V_LINE_ITEMS_ENRICHED
  COMMENT = 'DEMO: Line items with GL code descriptions (Expires: 2026-05-08)'
AS
SELECT
    li.LINE_ID,
    li.INVOICE_ID,
    h.INVOICE_NUMBER,
    h.PROPERTY,
    li.DESCRIPTION,
    li.QUANTITY,
    li.UNIT_PRICE,
    li.LINE_TOTAL,
    li.GL_CODE_SUGGESTED,
    g_suggested.GL_DESCRIPTION  AS GL_SUGGESTED_DESC,
    g_suggested.CATEGORY        AS GL_SUGGESTED_CATEGORY,
    li.GL_CODE_CONFIDENCE,
    li.GL_CODE_CONFIRMED,
    g_confirmed.GL_DESCRIPTION  AS GL_CONFIRMED_DESC,
    li.REVIEWER_OVERRIDE,
    CASE
        WHEN li.GL_CODE_CONFIRMED IS NOT NULL THEN 'Human Confirmed'
        WHEN li.GL_CODE_CONFIDENCE >= 0.85    THEN 'AI Suggested (High)'
        WHEN li.GL_CODE_CONFIDENCE >= 0.70    THEN 'AI Suggested (Medium)'
        ELSE 'Needs Review'
    END AS CLASSIFICATION_STATUS
FROM INVOICE_LINE_ITEMS li
JOIN INVOICE_HEADER h
    ON li.INVOICE_ID = h.INVOICE_ID
LEFT JOIN GL_CODES g_suggested
    ON li.GL_CODE_SUGGESTED = g_suggested.GL_CODE
LEFT JOIN GL_CODES g_confirmed
    ON li.GL_CODE_CONFIRMED = g_confirmed.GL_CODE;

-- Pipeline metrics summary
CREATE OR REPLACE VIEW V_PIPELINE_METRICS
  COMMENT = 'DEMO: Aggregated pipeline KPIs (Expires: 2026-05-08)'
AS
SELECT
    COUNT(*)                                                      AS TOTAL_INVOICES,
    COUNT_IF(STATUS = 'PROCESSED')                                AS PROCESSED_COUNT,
    COUNT_IF(STATUS = 'REVIEW')                                   AS REVIEW_COUNT,
    COUNT_IF(STATUS = 'PENDING')                                  AS PENDING_COUNT,
    ROUND(COUNT_IF(STATUS = 'PROCESSED') / NULLIF(COUNT(*), 0) * 100, 1)
                                                                  AS AUTO_APPROVAL_RATE,
    ROUND(AVG(VALIDATION_SCORE), 2)                               AS AVG_VALIDATION_SCORE,
    SUM(CASE WHEN STATUS = 'PROCESSED' THEN TOTAL_AMOUNT ELSE 0 END)
                                                                  AS TOTAL_PROCESSED_SPEND,
    SUM(CASE WHEN STATUS = 'REVIEW' THEN TOTAL_AMOUNT ELSE 0 END)
                                                                  AS TOTAL_PENDING_SPEND,
    ROUND(AVG(CASE WHEN APPROVED_TS IS NOT NULL
        THEN DATEDIFF('second', EXTRACTION_TS, APPROVED_TS)
        END), 0)                                                  AS AVG_PROCESSING_SECONDS
FROM INVOICE_HEADER;

-- Spend by property and vendor
CREATE OR REPLACE VIEW V_SPEND_ANALYSIS
  COMMENT = 'DEMO: Spend breakdown by property and vendor (Expires: 2026-05-08)'
AS
SELECT
    h.PROPERTY,
    COALESCE(v.VENDOR_NAME, h.VENDOR_NAME_RAW) AS VENDOR_NAME,
    g.CATEGORY                                  AS GL_CATEGORY,
    g.GL_DESCRIPTION,
    COUNT(DISTINCT h.INVOICE_ID)                AS INVOICE_COUNT,
    SUM(li.LINE_TOTAL)                          AS TOTAL_SPEND,
    AVG(li.GL_CODE_CONFIDENCE)                  AS AVG_GL_CONFIDENCE
FROM INVOICE_HEADER h
JOIN INVOICE_LINE_ITEMS li
    ON h.INVOICE_ID = li.INVOICE_ID
LEFT JOIN VENDOR_MASTER v
    ON h.VENDOR_ID_RESOLVED = v.VENDOR_ID
LEFT JOIN GL_CODES g
    ON COALESCE(li.GL_CODE_CONFIRMED, li.GL_CODE_SUGGESTED) = g.GL_CODE
WHERE h.STATUS = 'PROCESSED'
GROUP BY h.PROPERTY, COALESCE(v.VENDOR_NAME, h.VENDOR_NAME_RAW), g.CATEGORY, g.GL_DESCRIPTION;

SELECT 'Views created' AS status;
