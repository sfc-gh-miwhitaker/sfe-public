/*==============================================================================
CLASSIFICATION APPROACH 3: Cortex AI_COMPLETE — Robust Pipeline
Multi-step pipeline with:
  - Structured JSON output via response_format schema
  - Hierarchical classification (Category > Subcategory > Attributes)
  - Confidence scoring
  - Multi-language handling built in
  - Batch processing with error handling
Production-ready pattern.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

TRUNCATE TABLE IF EXISTS STG_CLASSIFIED_CORTEX_ROBUST;

-- Build the valid taxonomy as context for the prompt
CREATE OR REPLACE TEMPORARY TABLE TEMP_TAXONOMY_CONTEXT AS
SELECT LISTAGG(
    CONCAT('- ', category, ' > ', subcategory),
    '\n'
) WITHIN GROUP (ORDER BY sort_order) AS taxonomy_text
FROM RAW_CATEGORY_TAXONOMY;

-- Classify with structured output, confidence, and language detection
INSERT INTO STG_CLASSIFIED_CORTEX_ROBUST
    (product_id, detected_language, predicted_category, predicted_subcategory,
     confidence_score, attributes, raw_response, model_used)
WITH classified AS (
    SELECT
        p.product_id,
        AI_COMPLETE(
            model => 'llama3.1-70b',
            prompt => CONCAT(
                'You are an expert product classifier for an international bakery/donut company operating in 6 markets. ',
                'You must classify products accurately regardless of the language they are written in.\n\n',

                '## Valid Taxonomy (you MUST pick from this list):\n',
                tx.taxonomy_text, '\n\n',

                '## Instructions:\n',
                '1. Detect the language of the product name and description.\n',
                '2. Classify the product into the BEST matching category and subcategory from the taxonomy above.\n',
                '3. Assign a confidence score from 0.0 to 1.0.\n',
                '4. Extract key attributes (flavor, topping, filling, coating) if identifiable.\n',
                '5. If the product name is just a filename (e.g., IMG_xxx.jpg) with no description, ',
                   'classify as best you can from the filename and set confidence low.\n\n',

                '## Product to Classify:\n',
                'Name: ', p.product_name, '\n',
                COALESCE(CONCAT('Description: ', p.product_description, '\n'), ''),
                'Market: ', p.market_code, '\n',
                'Language: ', p.language_code, '\n',
                COALESCE(CONCAT('Raw category: ', p.raw_category_string, '\n'), '')
            ),
            response_format => {
                'type': 'json',
                'schema': {
                    'type': 'object',
                    'properties': {
                        'detected_language': {'type': 'string', 'description': 'ISO language code detected'},
                        'category': {'type': 'string', 'description': 'Top-level category from taxonomy'},
                        'subcategory': {'type': 'string', 'description': 'Subcategory from taxonomy'},
                        'confidence': {'type': 'number', 'description': 'Classification confidence 0.0-1.0'},
                        'attributes': {
                            'type': 'object',
                            'properties': {
                                'flavor': {'type': 'string'},
                                'topping': {'type': 'string'},
                                'filling': {'type': 'string'},
                                'coating': {'type': 'string'}
                            }
                        }
                    },
                    'required': ['detected_language', 'category', 'subcategory', 'confidence']
                }
            }
        ) AS raw_json
    FROM RAW_PRODUCTS p
    CROSS JOIN TEMP_TAXONOMY_CONTEXT tx
)
SELECT
    product_id,
    TRY_PARSE_JSON(raw_json):detected_language::VARCHAR     AS detected_language,
    TRY_PARSE_JSON(raw_json):category::VARCHAR              AS predicted_category,
    TRY_PARSE_JSON(raw_json):subcategory::VARCHAR           AS predicted_subcategory,
    TRY_PARSE_JSON(raw_json):confidence::NUMBER(5,4)        AS confidence_score,
    TRY_PARSE_JSON(raw_json):attributes                     AS attributes,
    raw_json                                                AS raw_response,
    'llama3.1-70b'                                          AS model_used
FROM classified;

DROP TABLE IF EXISTS TEMP_TAXONOMY_CONTEXT;
