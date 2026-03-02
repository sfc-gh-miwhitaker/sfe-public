/*==============================================================================
03_SILVER / 02_CORTEX_ENRICHMENT
Cortex AI-enriched dynamic tables running in incremental refresh mode.
Cortex functions in dynamic table SELECT clauses are supported since Sep 2025.
With incremental refresh, Cortex only processes NEW rows -- costs scale with
data velocity, not volume.

Three patterns demonstrated:
  1. AI_SENTIMENT  -- category-level sentiment on invoice notes
  2. AI_COMPLETE   -- structured output extraction (schema-drift-resistant)
  3. AI_CLASSIFY   -- multi-label customer profile classification

Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- 1. ENRICHED_INVOICE_NOTES
--    AI_SENTIMENT with custom categories on invoice private notes.
--    Chains off STG_INVOICE via DOWNSTREAM lag (auto-refreshes when upstream updates).
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE ENRICHED_INVOICE_NOTES
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Invoice notes enriched with AI_SENTIMENT (Expires: 2026-03-29)'
AS
SELECT
    invoice_id,
    doc_number,
    customer_id,
    private_note,
    AI_SENTIMENT(
        private_note,
        ['urgency', 'satisfaction', 'payment_intent']
    ) AS note_sentiment,
    fetched_at
FROM STG_INVOICE
WHERE private_note IS NOT NULL;

-------------------------------------------------------------------------------
-- 2. CORTEX_PARSED_INVOICE
--    AI_COMPLETE structured outputs for schema-drift-resistant extraction.
--    Instead of hard-coded JSON paths (01_dynamic_tables.sql), this uses an LLM
--    to extract fields from the raw payload -- resilient to upstream schema changes.
--
--    TEACHING NOTE: Run this side-by-side with STG_INVOICE to show both approaches.
--    Traditional paths are faster/cheaper; Cortex extraction is more flexible.
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE CORTEX_PARSED_INVOICE
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Cortex AI_COMPLETE structured extraction from raw JSON (Expires: 2026-03-29)'
AS
SELECT
    qbo_id,
    AI_COMPLETE(
        'llama3.3-70b',
        'Extract the following fields from this QuickBooks invoice JSON. '
        || 'Return only the structured fields, nothing else.\n\n'
        || raw_payload::VARCHAR,
        response_format => TYPE OBJECT(
            invoice_id     VARCHAR COMMENT 'The Id field',
            customer_name  VARCHAR COMMENT 'The CustomerRef name',
            doc_number     VARCHAR COMMENT 'The DocNumber field',
            total_amount   NUMBER  COMMENT 'The TotalAmt field',
            balance        NUMBER  COMMENT 'The Balance field',
            line_item_count NUMBER COMMENT 'Count of items in the Line array'
        )
    ):structured_output[0].raw_message AS extracted,
    fetched_at
FROM RAW_INVOICE
QUALIFY ROW_NUMBER() OVER (PARTITION BY qbo_id ORDER BY fetched_at DESC) = 1;

-------------------------------------------------------------------------------
-- 3. ENRICHED_CUSTOMER_PROFILE
--    AI_CLASSIFY for multi-label customer profiling based on billing attributes.
--    Uses few-shot examples for more deterministic classification.
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE ENRICHED_CUSTOMER_PROFILE
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = SFE_QB_API_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'DEMO: Customer profiles enriched with AI_CLASSIFY (Expires: 2026-03-29)'
AS
SELECT
    customer_id,
    display_name,
    company_name,
    email,
    bill_addr_state,
    balance,
    AI_CLASSIFY(
        CONCAT(
            'Company: ', COALESCE(company_name, display_name),
            '. State: ', COALESCE(bill_addr_state, 'unknown'),
            '. Current AR balance: $', balance::VARCHAR
        ),
        ['enterprise', 'mid-market', 'small-business', 'startup'],
        {
            'task_description': 'Classify the business size segment based on company name and financials',
            'examples': [
                {
                    'input': 'Company: Stark Enterprises. State: NY. Current AR balance: $28000',
                    'labels': ['enterprise'],
                    'explanation': 'Large, well-known enterprise with high AR balance'
                },
                {
                    'input': 'Company: Initech LLC. State: IL. Current AR balance: $0',
                    'labels': ['mid-market'],
                    'explanation': 'LLC with moderate presence, zero current balance'
                }
            ]
        }
    ):labels AS size_segments,
    fetched_at
FROM STG_CUSTOMER;
