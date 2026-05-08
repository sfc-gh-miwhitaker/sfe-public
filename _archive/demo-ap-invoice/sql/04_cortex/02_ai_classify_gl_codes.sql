/*==============================================================================
AI_CLASSIFY GL CODES - AP Invoice Pipeline
Classifies line item descriptions into GL account codes.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-08
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.AP_INVOICE;

----------------------------------------------------------------------
-- Stored procedure: classify a single line item description
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SP_CLASSIFY_LINE_ITEM(LINE_ITEM_ID NUMBER)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'DEMO: Classifies a line item description into GL codes using AI_CLASSIFY (Expires: 2026-05-08)'
AS
$$
DECLARE
    item_desc VARCHAR;
    gl_categories VARIANT;
    classification VARIANT;
    suggested_gl VARCHAR;
BEGIN
    SELECT DESCRIPTION INTO item_desc
    FROM INVOICE_LINE_ITEMS
    WHERE LINE_ID = :LINE_ITEM_ID;

    SELECT ARRAY_AGG(
        OBJECT_CONSTRUCT(
            'label', GL_CODE,
            'description', GL_DESCRIPTION || ' (' || CATEGORY || ')'
        )
    ) INTO gl_categories
    FROM GL_CODES;

    SELECT AI_CLASSIFY(
        :item_desc,
        :gl_categories,
        {
            'task_description': 'Classify this invoice line item into the correct GL account code for a gaming and hospitality company'
        }
    ) INTO classification;

    suggested_gl := classification:labels[0]::VARCHAR;

    UPDATE INVOICE_LINE_ITEMS
    SET GL_CODE_SUGGESTED = :suggested_gl
    WHERE LINE_ID = :LINE_ITEM_ID
      AND GL_CODE_CONFIRMED IS NULL;

    RETURN OBJECT_CONSTRUCT(
        'line_id', LINE_ITEM_ID,
        'description', item_desc,
        'suggested_gl', suggested_gl,
        'full_result', classification
    );
END;
$$;

----------------------------------------------------------------------
-- Stored procedure: batch-classify all unclassified line items
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SP_CLASSIFY_ALL_PENDING()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: Batch GL classification for all unclassified line items (Expires: 2026-05-08)'
AS
$$
DECLARE
    classified_count NUMBER DEFAULT 0;
BEGIN
    -- Build GL categories array once
    LET gl_categories VARIANT := (
        SELECT ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'label', GL_CODE,
                'description', GL_DESCRIPTION || ' (' || CATEGORY || ')'
            )
        ) FROM GL_CODES
    );

    -- Classify and update in one pass
    MERGE INTO INVOICE_LINE_ITEMS tgt
    USING (
        SELECT
            li.LINE_ID,
            AI_CLASSIFY(
                li.DESCRIPTION,
                :gl_categories,
                {'task_description': 'Classify this invoice line item into the correct GL account code for a gaming and hospitality company'}
            ):labels[0]::VARCHAR AS SUGGESTED_GL
        FROM INVOICE_LINE_ITEMS li
        WHERE li.GL_CODE_SUGGESTED IS NULL
          AND li.GL_CODE_CONFIRMED IS NULL
          AND li.DESCRIPTION IS NOT NULL
    ) src
    ON tgt.LINE_ID = src.LINE_ID
    WHEN MATCHED THEN UPDATE SET
        tgt.GL_CODE_SUGGESTED = src.SUGGESTED_GL;

    classified_count := SQLROWCOUNT;

    RETURN 'Classified ' || classified_count || ' line items';
END;
$$;

SELECT 'AI_CLASSIFY GL code procedures created' AS status;
