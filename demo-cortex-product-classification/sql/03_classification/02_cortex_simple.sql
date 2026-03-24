/*==============================================================================
CLASSIFICATION APPROACH 2: Cortex AI — Translate & Classify
AI_TRANSLATE + AI_COMPLETE in a single query.
Mirrors the original use case: translate product names to English, then classify.
~15 lines of core SQL. Handles any language out of the box.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

TRUNCATE TABLE IF EXISTS STG_CLASSIFIED_CORTEX_SIMPLE;

INSERT INTO STG_CLASSIFIED_CORTEX_SIMPLE (product_id, predicted_category, predicted_subcategory, raw_response, model_used)
SELECT
    p.product_id,
    TRIM(response:category::VARCHAR)        AS predicted_category,
    TRIM(response:subcategory::VARCHAR)      AS predicted_subcategory,
    raw_text                                 AS raw_response,
    'auto'                                   AS model_used
FROM RAW_PRODUCTS p,
    LATERAL (
        SELECT AI_COMPLETE(
            model => 'snowflake-llama-3.3-70b',
            prompt => CONCAT(
                'You are a product classifier for a bakery/donut company. ',
                'Classify the following product into exactly one category and subcategory. ',
                'Categories: Glazed, Frosted, Filled, Cake, Specialty, Seasonal, Beverages, Merchandise. ',
                'Respond ONLY with JSON: {"category": "...", "subcategory": "..."}\n\n',
                'Product name (translated): ',
                AI_TRANSLATE(p.product_name, '', 'en'),
                CASE WHEN p.product_description IS NOT NULL
                     THEN CONCAT('\nDescription (translated): ',
                                 AI_TRANSLATE(p.product_description, '', 'en'))
                     ELSE '' END,
                CASE WHEN p.market_code IS NOT NULL
                     THEN CONCAT('\nMarket: ', p.market_code)
                     ELSE '' END
            )
        ) AS raw_text
    ) llm,
    LATERAL (
        SELECT TRY_PARSE_JSON(llm.raw_text) AS response
    ) parsed;
