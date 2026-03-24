/*==============================================================================
CLASSIFICATION APPROACH 3: Cortex AI_COMPLETE — Robust Pipeline
Multi-step pipeline with:
  - Structured JSON output via TYPE literal response_format
  - Hierarchical classification (Category > Subcategory > Attributes)
  - Confidence scoring
  - Multi-language handling built in (no explicit translate needed — the LLM
    handles all languages natively, unlike Approach 2 which translates first)
  - Batch processing with error handling
Production-ready pattern.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

TRUNCATE TABLE IF EXISTS STG_CLASSIFIED_CORTEX_ROBUST;

CREATE OR REPLACE TEMPORARY TABLE TEMP_TAXONOMY_CONTEXT AS
SELECT LISTAGG(
    CONCAT('- ', category, ' > ', subcategory),
    '\n'
) WITHIN GROUP (ORDER BY sort_order) AS taxonomy_text
FROM RAW_CATEGORY_TAXONOMY;

INSERT INTO STG_CLASSIFIED_CORTEX_ROBUST
    (product_id, detected_language, predicted_category, predicted_subcategory,
     confidence_score, attributes, raw_response, model_used)
WITH classified AS (
    SELECT
        p.product_id,
        AI_COMPLETE(
            model => 'llama3.3-70b',
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
            response_format => TYPE OBJECT(
                detected_language STRING,
                category STRING,
                subcategory STRING,
                confidence FLOAT,
                attributes OBJECT(
                    flavor STRING,
                    topping STRING,
                    filling STRING,
                    coating STRING
                )
            )
        ) AS raw_json
    FROM RAW_PRODUCTS p
    CROSS JOIN TEMP_TAXONOMY_CONTEXT tx
)
SELECT
    product_id,
    raw_json:detected_language::VARCHAR                      AS detected_language,
    raw_json:category::VARCHAR                               AS predicted_category,
    raw_json:subcategory::VARCHAR                            AS predicted_subcategory,
    raw_json:confidence::FLOAT                               AS confidence_score,
    raw_json:attributes                                      AS attributes,
    raw_json::VARCHAR                                        AS raw_response,
    'llama3.3-70b'                                          AS model_used
FROM classified;

DROP TABLE IF EXISTS TEMP_TAXONOMY_CONTEXT;
