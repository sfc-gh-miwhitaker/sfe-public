/*==============================================================================
CLASSIFICATION APPROACH 2: Cortex AI_COMPLETE — Simple
Single AI_COMPLETE() call with a classification prompt.
~10 lines of core SQL. Handles multiple languages out of the box.
Shows how fast you can get started with AI classification.
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
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'llama3.1-70b',
            CONCAT(
                'You are a product classifier for a bakery/donut company. ',
                'Classify the following product into exactly one category and subcategory. ',
                'Categories: Glazed, Frosted, Filled, Cake, Specialty, Seasonal, Beverages, Merchandise. ',
                'Respond ONLY with JSON: {"category": "...", "subcategory": "..."}\n\n',
                'Product name: ', p.product_name,
                CASE WHEN p.product_description IS NOT NULL
                     THEN CONCAT('\nDescription: ', p.product_description)
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
