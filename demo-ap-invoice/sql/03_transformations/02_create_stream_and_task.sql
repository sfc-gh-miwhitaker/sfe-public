/*==============================================================================
STREAM & TASK - AP Invoice Pipeline
Automated processing: new files on stage trigger extraction pipeline.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-08
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.AP_INVOICE;

----------------------------------------------------------------------
-- Stream: tracks new rows in INVOICE_HEADER for downstream processing
----------------------------------------------------------------------
CREATE STREAM IF NOT EXISTS INVOICE_HEADER_STREAM
    ON TABLE INVOICE_HEADER
    APPEND_ONLY = TRUE
    COMMENT = 'DEMO: Captures new invoice extractions for validation pipeline (Expires: 2026-05-08)';

----------------------------------------------------------------------
-- Stored procedure: validates extracted invoice and routes to review
-- queue or auto-approves based on validation score threshold.
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SP_VALIDATE_AND_ROUTE(THRESHOLD NUMBER)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: Validates new extractions and routes low-scoring invoices to review (Expires: 2026-05-08)'
AS
$$
DECLARE
    routed_count NUMBER DEFAULT 0;
    approved_count NUMBER DEFAULT 0;
BEGIN
    -- Route low-scoring invoices to review queue
    INSERT INTO REVIEW_QUEUE (INVOICE_ID, FLAGGED_FIELDS, VALIDATION_SCORE)
    SELECT
        s.INVOICE_ID,
        ARRAY_CONSTRUCT_COMPACT(
            IFF(s.VENDOR_ID_RESOLVED IS NULL, 'VENDOR_ID_RESOLVED', NULL),
            IFF(s.INVOICE_NUMBER IS NULL, 'INVOICE_NUMBER', NULL),
            IFF(s.INVOICE_DATE IS NULL, 'INVOICE_DATE', NULL),
            IFF(s.TOTAL_AMOUNT IS NULL, 'TOTAL_AMOUNT', NULL),
            IFF(s.PO_REFERENCE IS NULL, 'PO_REFERENCE', NULL)
        ),
        s.VALIDATION_SCORE
    FROM INVOICE_HEADER_STREAM s
    WHERE s.VALIDATION_SCORE < :THRESHOLD
      AND s.STATUS = 'PENDING';

    routed_count := SQLROWCOUNT;

    -- Auto-approve high-scoring invoices
    UPDATE INVOICE_HEADER
    SET STATUS = 'PROCESSED',
        APPROVED_BY = 'SYSTEM',
        APPROVED_TS = CURRENT_TIMESTAMP()
    WHERE INVOICE_ID IN (
        SELECT INVOICE_ID
        FROM INVOICE_HEADER
        WHERE VALIDATION_SCORE >= :THRESHOLD
          AND STATUS = 'PENDING'
    );

    approved_count := SQLROWCOUNT;

    -- Log actions to audit trail
    INSERT INTO AUDIT_LOG (INVOICE_ID, ACTION, FIELD_NAME, OLD_VALUE, NEW_VALUE, ACTOR, ACTOR_TYPE)
    SELECT INVOICE_ID, 'AUTO_APPROVED', 'STATUS', 'PENDING', 'PROCESSED', 'SYSTEM', 'SYSTEM'
    FROM INVOICE_HEADER
    WHERE APPROVED_BY = 'SYSTEM'
      AND APPROVED_TS >= DATEADD('minute', -1, CURRENT_TIMESTAMP());

    RETURN 'Validation complete: ' || approved_count || ' auto-approved, '
           || routed_count || ' routed to review';
END;
$$;

----------------------------------------------------------------------
-- Task: runs validation every 5 minutes when new data arrives
----------------------------------------------------------------------
CREATE TASK IF NOT EXISTS VALIDATE_INVOICES_TASK
    WAREHOUSE = SFE_AP_INVOICE_WH
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('INVOICE_HEADER_STREAM')
    COMMENT = 'DEMO: Auto-validates new extractions using stream trigger (Expires: 2026-05-08)'
AS
    CALL SP_VALIDATE_AND_ROUTE(0.75);

-- Task is created SUSPENDED by default. Resume in Streamlit or manually:
-- ALTER TASK VALIDATE_INVOICES_TASK RESUME;

----------------------------------------------------------------------
-- Stored procedure: process a PDF invoice end-to-end
-- Extracts fields, matches vendor, classifies GL codes, computes score
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SP_PROCESS_INVOICE(FILE_PATH VARCHAR, PROPERTY VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'DEMO: End-to-end invoice processing - extract, match, classify, score (Expires: 2026-05-08)'
AS
$$
DECLARE
    extraction VARIANT;
    vendor_name_raw VARCHAR;
    vendor_id_match NUMBER;
    invoice_num VARCHAR;
    invoice_dt DATE;
    po_ref VARCHAR;
    total_amt NUMBER(12,2);
    score NUMBER(5,2) DEFAULT 0;
    new_invoice_id NUMBER;
BEGIN
    -- Step 1: AI_EXTRACT structured fields from PDF
    SELECT AI_EXTRACT(
        file => TO_FILE('@RAW_INVOICE_STAGE', :FILE_PATH),
        responseFormat => {
            'vendor_name': 'What is the vendor or supplier name on this invoice?',
            'invoice_number': 'What is the invoice number?',
            'invoice_date': 'What is the invoice date?',
            'po_reference': 'What is the purchase order or PO number?',
            'total_amount': 'What is the total amount due on this invoice?'
        }
    ) INTO extraction;

    vendor_name_raw := extraction:response:vendor_name::VARCHAR;
    invoice_num := extraction:response:invoice_number::VARCHAR;
    po_ref := extraction:response:po_reference::VARCHAR;
    total_amt := TRY_TO_NUMBER(REGEXP_REPLACE(extraction:response:total_amount::VARCHAR, '[^0-9.]', ''), 12, 2);

    BEGIN
        invoice_dt := TRY_TO_DATE(extraction:response:invoice_date::VARCHAR);
    EXCEPTION WHEN OTHER THEN
        invoice_dt := NULL;
    END;

    -- Step 2: Fuzzy-match vendor against VENDOR_MASTER
    SELECT VENDOR_ID INTO vendor_id_match
    FROM VENDOR_MASTER
    WHERE VENDOR_NAME = :vendor_name_raw
       OR ARRAY_CONTAINS(:vendor_name_raw::VARIANT, VENDOR_ALIASES)
    QUALIFY ROW_NUMBER() OVER (ORDER BY JAROWINKLER_SIMILARITY(VENDOR_NAME, :vendor_name_raw) DESC) = 1;

    -- Step 3: Compute validation score
    score := 0;
    IF (vendor_name_raw IS NOT NULL AND LENGTH(vendor_name_raw) > 0) THEN score := score + 0.15; END IF;
    IF (invoice_num IS NOT NULL AND LENGTH(invoice_num) > 2) THEN score := score + 0.15; END IF;
    IF (invoice_dt IS NOT NULL) THEN score := score + 0.15; END IF;
    IF (total_amt IS NOT NULL AND total_amt > 0) THEN score := score + 0.15; END IF;
    IF (po_ref IS NOT NULL AND LENGTH(po_ref) > 0) THEN score := score + 0.10; END IF;
    IF (vendor_id_match IS NOT NULL) THEN score := score + 0.20; END IF;
    IF (extraction:error IS NULL) THEN score := score + 0.10; END IF;

    -- Step 4: Insert into INVOICE_HEADER
    INSERT INTO INVOICE_HEADER (
        SOURCE_FILE, VENDOR_NAME_RAW, VENDOR_ID_RESOLVED,
        INVOICE_NUMBER, INVOICE_DATE, PO_REFERENCE,
        TOTAL_AMOUNT, PROPERTY, VALIDATION_SCORE,
        STATUS, AI_EXTRACT_RAW
    ) VALUES (
        :FILE_PATH, :vendor_name_raw, :vendor_id_match,
        :invoice_num, :invoice_dt, :po_ref,
        :total_amt, :PROPERTY, :score,
        IFF(:score >= 0.75, 'PENDING', 'REVIEW'),
        :extraction
    );

    new_invoice_id := SQLROWCOUNT;

    -- Step 5: Log to audit trail
    INSERT INTO AUDIT_LOG (INVOICE_ID, ACTION, ACTOR, ACTOR_TYPE)
    SELECT MAX(INVOICE_ID), 'EXTRACTED', 'AI_EXTRACT', 'AI'
    FROM INVOICE_HEADER;

    RETURN OBJECT_CONSTRUCT(
        'invoice_id', new_invoice_id,
        'vendor_raw', vendor_name_raw,
        'vendor_matched', vendor_id_match IS NOT NULL,
        'validation_score', score,
        'status', IFF(score >= 0.75, 'PENDING', 'REVIEW')
    );
END;
$$;

SELECT 'Stream, task, and procedures created' AS status;
