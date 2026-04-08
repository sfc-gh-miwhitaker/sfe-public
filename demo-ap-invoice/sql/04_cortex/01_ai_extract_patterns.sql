/*==============================================================================
AI_EXTRACT PATTERNS - AP Invoice Pipeline
Example queries demonstrating AI_EXTRACT on invoice PDFs.
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-08

NOTE: These patterns require PDF files uploaded to @RAW_INVOICE_STAGE.
The demo ships with pre-populated sample data. Use these patterns when
processing your own invoices.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.AP_INVOICE;

----------------------------------------------------------------------
-- Pattern 1: Extract header fields from a single invoice PDF
----------------------------------------------------------------------
-- SELECT AI_EXTRACT(
--     file => TO_FILE('@RAW_INVOICE_STAGE', 'your_invoice.pdf'),
--     responseFormat => {
--         'vendor_name': 'What is the vendor or supplier name?',
--         'invoice_number': 'What is the invoice number or reference?',
--         'invoice_date': 'What is the invoice date (YYYY-MM-DD)?',
--         'po_reference': 'What is the purchase order or PO number?',
--         'total_amount': 'What is the total amount due?',
--         'currency': 'What currency is this invoice in (3-letter code)?'
--     }
-- );

----------------------------------------------------------------------
-- Pattern 2: Extract line items as a table from an invoice PDF
----------------------------------------------------------------------
-- SELECT AI_EXTRACT(
--     file => TO_FILE('@RAW_INVOICE_STAGE', 'your_invoice.pdf'),
--     responseFormat => {
--         'schema': {
--             'type': 'object',
--             'properties': {
--                 'line_items': {
--                     'description': 'Invoice line items table',
--                     'type': 'object',
--                     'column_ordering': ['description', 'quantity', 'unit_price', 'total'],
--                     'properties': {
--                         'description': {'description': 'Item description', 'type': 'array'},
--                         'quantity':    {'description': 'Quantity',         'type': 'array'},
--                         'unit_price':  {'description': 'Unit Price',      'type': 'array'},
--                         'total':       {'description': 'Line Total',      'type': 'array'}
--                     }
--                 }
--             }
--         }
--     }
-- );

----------------------------------------------------------------------
-- Pattern 3: Combined extraction (header + line items in one call)
----------------------------------------------------------------------
-- SELECT AI_EXTRACT(
--     file => TO_FILE('@RAW_INVOICE_STAGE', 'your_invoice.pdf'),
--     responseFormat => {
--         'schema': {
--             'type': 'object',
--             'properties': {
--                 'vendor_name': {
--                     'description': 'Vendor or supplier company name',
--                     'type': 'string'
--                 },
--                 'invoice_number': {
--                     'description': 'Invoice number or reference ID',
--                     'type': 'string'
--                 },
--                 'total_amount': {
--                     'description': 'Total amount due on invoice',
--                     'type': 'string'
--                 },
--                 'line_items': {
--                     'description': 'Invoice line items',
--                     'type': 'object',
--                     'column_ordering': ['description', 'quantity', 'unit_price', 'total'],
--                     'properties': {
--                         'description': {'description': 'Item description', 'type': 'array'},
--                         'quantity':    {'description': 'Quantity',         'type': 'array'},
--                         'unit_price':  {'description': 'Unit Price',      'type': 'array'},
--                         'total':       {'description': 'Line Total',      'type': 'array'}
--                     }
--                 }
--             }
--         }
--     }
-- );

----------------------------------------------------------------------
-- Pattern 4: Batch processing all PDFs on stage
----------------------------------------------------------------------
-- SELECT
--     relative_path AS file_name,
--     AI_EXTRACT(
--         file => TO_FILE('@RAW_INVOICE_STAGE', relative_path),
--         responseFormat => {
--             'vendor_name': 'Vendor or supplier name',
--             'invoice_number': 'Invoice number',
--             'invoice_date': 'Invoice date (YYYY-MM-DD)',
--             'total_amount': 'Total amount due'
--         }
--     ) AS extracted_data
-- FROM DIRECTORY(@RAW_INVOICE_STAGE)
-- WHERE relative_path LIKE '%.pdf';

----------------------------------------------------------------------
-- Pattern 5: End-to-end processing via stored procedure
----------------------------------------------------------------------
-- CALL SP_PROCESS_INVOICE('your_invoice.pdf', 'Resort East');

SELECT 'AI_EXTRACT patterns ready (see comments for usage)' AS status;
