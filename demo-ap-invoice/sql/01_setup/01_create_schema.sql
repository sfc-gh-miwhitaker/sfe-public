/*==============================================================================
SETUP - AP Invoice Pipeline
Creates schema, tables, stage, and supporting objects.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-08
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.AP_INVOICE;

-- Stage for raw PDF invoice files
CREATE STAGE IF NOT EXISTS RAW_INVOICE_STAGE
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'DEMO: Landing zone for PDF invoices (Expires: 2026-05-08)';

-- Reference: canonical vendor list for fuzzy matching
CREATE TABLE IF NOT EXISTS VENDOR_MASTER (
    VENDOR_ID        NUMBER AUTOINCREMENT PRIMARY KEY,
    VENDOR_NAME      VARCHAR NOT NULL,
    VENDOR_ALIASES   ARRAY,
    PAYMENT_TERMS    VARCHAR DEFAULT 'NET30'
) COMMENT = 'DEMO: Vendor master for name resolution (Expires: 2026-05-08)';

-- Reference: GL account taxonomy for AI_CLASSIFY
CREATE TABLE IF NOT EXISTS GL_CODES (
    GL_CODE          VARCHAR(10) PRIMARY KEY,
    GL_DESCRIPTION   VARCHAR NOT NULL,
    CATEGORY         VARCHAR NOT NULL
) COMMENT = 'DEMO: GL code taxonomy for classification (Expires: 2026-05-08)';

-- Extracted invoice headers (one row per PDF)
CREATE TABLE IF NOT EXISTS INVOICE_HEADER (
    INVOICE_ID          NUMBER AUTOINCREMENT PRIMARY KEY,
    SOURCE_FILE         VARCHAR NOT NULL,
    VENDOR_NAME_RAW     VARCHAR,
    VENDOR_ID_RESOLVED  NUMBER,
    INVOICE_NUMBER      VARCHAR,
    INVOICE_DATE        DATE,
    PO_REFERENCE        VARCHAR,
    TOTAL_AMOUNT        NUMBER(12,2),
    CURRENCY            VARCHAR(3) DEFAULT 'USD',
    PROPERTY            VARCHAR,
    EXTRACTION_TS       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    VALIDATION_SCORE    NUMBER(5,2),
    STATUS              VARCHAR DEFAULT 'PENDING',
    AI_EXTRACT_RAW      VARIANT,
    APPROVED_BY         VARCHAR,
    APPROVED_TS         TIMESTAMP_NTZ
) COMMENT = 'DEMO: Extracted invoice headers with validation scores (Expires: 2026-05-08)';

-- Extracted line items (many per invoice)
CREATE TABLE IF NOT EXISTS INVOICE_LINE_ITEMS (
    LINE_ID              NUMBER AUTOINCREMENT PRIMARY KEY,
    INVOICE_ID           NUMBER NOT NULL,
    DESCRIPTION          VARCHAR,
    QUANTITY             NUMBER(10,2),
    UNIT_PRICE           NUMBER(12,2),
    LINE_TOTAL           NUMBER(12,2),
    GL_CODE_SUGGESTED    VARCHAR(10),
    GL_CODE_CONFIDENCE   NUMBER(5,4),
    GL_CODE_CONFIRMED    VARCHAR(10),
    REVIEWER_OVERRIDE    BOOLEAN DEFAULT FALSE
) COMMENT = 'DEMO: Invoice line items with GL classification (Expires: 2026-05-08)';

-- Human review queue for low-scoring extractions
CREATE TABLE IF NOT EXISTS REVIEW_QUEUE (
    QUEUE_ID            NUMBER AUTOINCREMENT PRIMARY KEY,
    INVOICE_ID          NUMBER NOT NULL,
    FLAGGED_FIELDS      ARRAY,
    VALIDATION_SCORE    NUMBER(5,2),
    REVIEWER_ID         VARCHAR,
    REVIEWED_TS         TIMESTAMP_NTZ,
    RESOLUTION          VARCHAR,
    NOTES               VARCHAR
) COMMENT = 'DEMO: Human-in-the-loop review queue (Expires: 2026-05-08)';

-- Audit log for every decision
CREATE TABLE IF NOT EXISTS AUDIT_LOG (
    LOG_ID              NUMBER AUTOINCREMENT PRIMARY KEY,
    INVOICE_ID          NUMBER NOT NULL,
    ACTION              VARCHAR NOT NULL,
    FIELD_NAME          VARCHAR,
    OLD_VALUE           VARCHAR,
    NEW_VALUE           VARCHAR,
    ACTOR               VARCHAR NOT NULL,
    ACTOR_TYPE          VARCHAR NOT NULL,
    ACTION_TS           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: Complete audit trail for every AI and human decision (Expires: 2026-05-08)';

SELECT 'Schema setup complete' AS status;
