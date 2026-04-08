/*==============================================================================
SEMANTIC VIEW - AP Invoice Pipeline
Cortex Analyst semantic view over processed invoices for NL analytics.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-08
==============================================================================*/

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared schema for semantic views across demo projects';

CREATE OR REPLACE SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AP_INVOICE

    TABLES (
        inv AS SNOWFLAKE_EXAMPLE.AP_INVOICE.PROCESSED_INVOICES
            PRIMARY KEY (INVOICE_ID)
            WITH SYNONYMS = ('invoice', 'invoices', 'AP invoice', 'bill', 'bills')
            COMMENT = 'Processed AP invoices with vendor resolution and line item totals',

        lines AS SNOWFLAKE_EXAMPLE.AP_INVOICE.V_LINE_ITEMS_ENRICHED
            PRIMARY KEY (LINE_ID)
            WITH SYNONYMS = ('line item', 'line items', 'invoice detail', 'item')
            COMMENT = 'Invoice line items with GL classification status',

        spend AS SNOWFLAKE_EXAMPLE.AP_INVOICE.V_SPEND_ANALYSIS
            WITH SYNONYMS = ('spending', 'spend analysis', 'cost breakdown')
            COMMENT = 'Pre-aggregated spend by property, vendor, and GL category'
    )

    RELATIONSHIPS (
        inv_to_lines AS inv(INVOICE_ID) REFERENCES lines(INVOICE_ID)
    )

    FACTS (
        inv.TOTAL_AMOUNT  AS TOTAL_AMOUNT
            WITH SYNONYMS = ('amount', 'invoice total', 'total', 'invoice amount')
            COMMENT = 'Total invoice amount in the invoiced currency (typically USD)',

        inv.VALIDATION_SCORE  AS VALIDATION_SCORE
            WITH SYNONYMS = ('confidence', 'confidence score', 'quality score', 'extraction quality')
            COMMENT = 'Composite validation score (0.0-1.0) computed from field completeness, format checks, and vendor matching. Threshold for auto-approval is 0.75',

        inv.PROCESSING_SECONDS  AS PROCESSING_SECONDS
            WITH SYNONYMS = ('processing time', 'time to approve', 'cycle time')
            COMMENT = 'Seconds elapsed between AI extraction and approval (auto or human)',

        lines.LINE_AMOUNT  AS LINE_TOTAL
            WITH SYNONYMS = ('line total', 'item amount', 'line item total')
            COMMENT = 'Total amount for a single line item (quantity * unit price)',

        lines.QUANTITY  AS QUANTITY
            WITH SYNONYMS = ('qty', 'item quantity', 'units')
            COMMENT = 'Quantity of items on the line',

        lines.UNIT_PRICE  AS UNIT_PRICE
            WITH SYNONYMS = ('price', 'unit cost', 'per-unit price')
            COMMENT = 'Price per unit for the line item',

        lines.GL_CONFIDENCE  AS GL_CODE_CONFIDENCE
            WITH SYNONYMS = ('classification confidence', 'GL confidence')
            COMMENT = 'AI_CLASSIFY confidence score for the suggested GL code (0.0-1.0)',

        spend.CATEGORY_SPEND  AS TOTAL_SPEND
            WITH SYNONYMS = ('category total', 'category spend')
            COMMENT = 'Total spend for a property/vendor/GL category combination',

        spend.CATEGORY_INVOICE_COUNT  AS INVOICE_COUNT
            WITH SYNONYMS = ('number of invoices', 'invoice count per category')
            COMMENT = 'Count of distinct invoices in a property/vendor/GL category grouping'
    )

    DIMENSIONS (
        inv.INVOICE_NUMBER  AS INVOICE_NUMBER
            WITH SYNONYMS = ('invoice num', 'invoice #', 'inv number')
            COMMENT = 'Unique invoice identifier assigned by the vendor',

        inv.INVOICE_DATE  AS INVOICE_DATE
            WITH SYNONYMS = ('date', 'invoice dt', 'billing date')
            COMMENT = 'Date the invoice was issued by the vendor',

        inv.PROPERTY  AS PROPERTY
            WITH SYNONYMS = ('resort', 'location', 'site', 'facility')
            COMMENT = 'Property or resort that received the goods/services. Values: Resort East, Resort Northeast, Resort North',

        inv.STATUS  AS STATUS
            WITH SYNONYMS = ('invoice status', 'processing status', 'approval status')
            COMMENT = 'Current processing status: PROCESSED (auto-approved), REVIEW (needs human review), or PENDING',

        inv.VENDOR_NAME  AS VENDOR_NAME_RESOLVED
            WITH SYNONYMS = ('vendor', 'supplier', 'company name', 'vendor name')
            COMMENT = 'Canonical vendor name after fuzzy matching against vendor master',

        inv.PO_REFERENCE  AS PO_REFERENCE
            WITH SYNONYMS = ('PO', 'purchase order', 'PO number', 'PO #')
            COMMENT = 'Associated purchase order reference number',

        inv.CURRENCY  AS CURRENCY
            WITH SYNONYMS = ('currency code')
            COMMENT = 'Invoice currency (3-letter ISO code, typically USD)',

        lines.LINE_DESCRIPTION  AS DESCRIPTION
            WITH SYNONYMS = ('item description', 'line item description', 'item')
            COMMENT = 'Description of the goods or services on a line item',

        lines.GL_CODE  AS GL_CODE_SUGGESTED
            WITH SYNONYMS = ('GL', 'GL account', 'account code', 'general ledger code')
            COMMENT = 'GL account code suggested by AI_CLASSIFY for the line item',

        lines.GL_DESCRIPTION  AS GL_SUGGESTED_DESC
            WITH SYNONYMS = ('GL name', 'account description', 'GL category')
            COMMENT = 'Human-readable description of the suggested GL code',

        lines.GL_CLASSIFICATION_STATUS  AS CLASSIFICATION_STATUS
            WITH SYNONYMS = ('classification status', 'GL status')
            COMMENT = 'Whether the GL code was AI-suggested, human-confirmed, or needs review',

        spend.SPEND_CATEGORY  AS GL_CATEGORY
            WITH SYNONYMS = ('expense category', 'cost category', 'spend type')
            COMMENT = 'High-level expense category: Operating or G&A'
    )

    METRICS (
        inv.TOTAL_INVOICE_SPEND AS SUM(inv.TOTAL_AMOUNT)
            WITH SYNONYMS = ('total spend', 'total AP spend', 'aggregate spend')
            COMMENT = 'Sum of all invoice amounts across the selected scope',

        inv.AVERAGE_INVOICE_AMOUNT AS AVG(inv.TOTAL_AMOUNT)
            WITH SYNONYMS = ('avg invoice', 'average bill', 'mean invoice amount')
            COMMENT = 'Average invoice amount across the selected scope',

        inv.INVOICE_COUNT AS COUNT(inv.INVOICE_ID)
            WITH SYNONYMS = ('number of invoices', 'how many invoices', 'invoice count')
            COMMENT = 'Total count of invoices in the selected scope',

        inv.AUTO_APPROVAL_RATE AS
            ROUND(COUNT_IF(inv.STATUS = 'PROCESSED') * 100.0 / NULLIF(COUNT(inv.INVOICE_ID), 0), 1)
            WITH SYNONYMS = ('approval rate', 'automation rate', 'straight-through rate')
            COMMENT = 'Percentage of invoices auto-approved without human intervention',

        inv.AVERAGE_VALIDATION_SCORE AS ROUND(AVG(inv.VALIDATION_SCORE), 2)
            WITH SYNONYMS = ('avg confidence', 'mean quality score')
            COMMENT = 'Average extraction validation score across selected invoices',

        inv.AVERAGE_PROCESSING_TIME AS ROUND(AVG(inv.PROCESSING_SECONDS), 0)
            WITH SYNONYMS = ('avg cycle time', 'mean processing time')
            COMMENT = 'Average seconds from extraction to approval',

        inv.PENDING_REVIEW_COUNT AS COUNT_IF(inv.STATUS = 'REVIEW')
            WITH SYNONYMS = ('pending count', 'review queue size', 'exceptions')
            COMMENT = 'Number of invoices currently pending human review',

        lines.TOTAL_LINE_SPEND AS SUM(lines.LINE_AMOUNT)
            WITH SYNONYMS = ('total line item spend', 'aggregate line spend')
            COMMENT = 'Sum of all line item amounts across selected scope'
    )

    COMMENT = 'DEMO: AP Invoice Pipeline analytics for Cortex Analyst NL queries (Expires: 2026-05-08)'

    AI_SQL_GENERATION '
        When a user asks about "spend" or "total spend", use TOTAL_INVOICE_SPEND metric on the inv table.
        When a user asks about "pending" or "review" invoices, filter by STATUS = ''REVIEW''.
        When a user asks about a specific property, filter PROPERTY dimension.
        "Approval rate" or "automation rate" refers to the AUTO_APPROVAL_RATE metric.
        "Processing time" refers to AVERAGE_PROCESSING_TIME in seconds; convert to minutes or hours for display.
        For vendor-level analysis, use VENDOR_NAME dimension.
        For GL-level analysis, use GL_CODE and GL_DESCRIPTION dimensions.
        Default time range is current month unless specified otherwise.
    ';

SELECT 'Semantic view SV_AP_INVOICE created in SEMANTIC_MODELS schema' AS status;
