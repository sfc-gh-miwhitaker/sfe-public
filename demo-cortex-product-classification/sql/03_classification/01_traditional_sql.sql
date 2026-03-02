/*==============================================================================
CLASSIFICATION APPROACH 1: Traditional SQL
CASE/LIKE/regex with keyword lookup tables.

Works for English keywords, breaks on Japanese/Portuguese/French/Spanish,
fails entirely on image-only products. Requires constant maintenance.
This is the "before" state.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

TRUNCATE TABLE IF EXISTS STG_CLASSIFIED_TRADITIONAL;

INSERT INTO STG_CLASSIFIED_TRADITIONAL (product_id, predicted_category, predicted_subcategory, match_method)
WITH keyword_matches AS (
    SELECT
        p.product_id,
        km.mapped_category,
        km.mapped_subcategory,
        km.priority,
        'keyword_lookup' AS match_method,
        ROW_NUMBER() OVER (
            PARTITION BY p.product_id
            ORDER BY km.priority ASC
        ) AS match_rank
    FROM RAW_PRODUCTS p
    INNER JOIN RAW_KEYWORD_MAP km
        ON LOWER(p.product_name) LIKE '%' || LOWER(km.keyword) || '%'
        AND km.language_code = 'en'
),

regex_matches AS (
    SELECT
        p.product_id,
        CASE
            WHEN REGEXP_LIKE(LOWER(p.product_name), '.*glaz(e|ed).*')
                THEN 'Glazed'
            WHEN REGEXP_LIKE(LOWER(p.product_name), '.*frost(ed|ing).*')
                THEN 'Frosted'
            WHEN REGEXP_LIKE(LOWER(p.product_name), '.*(fill|cream|custard|jelly|jam).*')
                THEN 'Filled'
            WHEN REGEXP_LIKE(LOWER(p.product_name), '.*(cake|cinnamon|blueberry).*')
                THEN 'Cake'
            WHEN REGEXP_LIKE(LOWER(p.product_name), '.*(cruller|old.?fashion|bear.?claw).*')
                THEN 'Specialty'
            WHEN REGEXP_LIKE(LOWER(p.product_name), '.*(pumpkin|peppermint|seasonal|holiday).*')
                THEN 'Seasonal'
            WHEN REGEXP_LIKE(LOWER(p.product_name), '.*(coffee|latte|tea|chocolate.*hot|hot.*chocolate).*')
                THEN 'Beverages'
            WHEN REGEXP_LIKE(LOWER(p.product_name), '.*(shirt|hoodie|mug|hat|tote|merch).*')
                THEN 'Merchandise'
            ELSE NULL
        END AS regex_category,
        'regex_pattern' AS match_method
    FROM RAW_PRODUCTS p
    WHERE p.product_id NOT IN (
        SELECT product_id FROM keyword_matches WHERE match_rank = 1
    )
),

raw_category_parse AS (
    SELECT
        p.product_id,
        CASE
            WHEN LOWER(p.raw_category_string) LIKE '%glazed%' OR LOWER(p.raw_category_string) LIKE '%glacé%'
                THEN 'Glazed'
            WHEN LOWER(p.raw_category_string) LIKE '%frosted%' OR LOWER(p.raw_category_string) LIKE '%givré%'
                THEN 'Frosted'
            WHEN LOWER(p.raw_category_string) LIKE '%filled%' OR LOWER(p.raw_category_string) LIKE '%fourré%' OR LOWER(p.raw_category_string) LIKE '%rellena%' OR LOWER(p.raw_category_string) LIKE '%recheado%'
                THEN 'Filled'
            WHEN LOWER(p.raw_category_string) LIKE '%cake%' OR LOWER(p.raw_category_string) LIKE '%gâteau%' OR LOWER(p.raw_category_string) LIKE '%pastel%' OR LOWER(p.raw_category_string) LIKE '%bolo%'
                THEN 'Cake'
            WHEN LOWER(p.raw_category_string) LIKE '%special%' OR LOWER(p.raw_category_string) LIKE '%spécialité%' OR LOWER(p.raw_category_string) LIKE '%especial%'
                THEN 'Specialty'
            WHEN LOWER(p.raw_category_string) LIKE '%season%' OR LOWER(p.raw_category_string) LIKE '%temporada%'
                THEN 'Seasonal'
            WHEN LOWER(p.raw_category_string) LIKE '%drink%' OR LOWER(p.raw_category_string) LIKE '%coffee%' OR LOWER(p.raw_category_string) LIKE '%café%' OR LOWER(p.raw_category_string) LIKE '%bebida%'
                THEN 'Beverages'
            WHEN LOWER(p.raw_category_string) LIKE '%merch%' OR LOWER(p.raw_category_string) LIKE '%boutique%' OR LOWER(p.raw_category_string) LIKE '%tienda%' OR LOWER(p.raw_category_string) LIKE '%loja%'
                THEN 'Merchandise'
            ELSE NULL
        END AS parsed_category,
        'raw_category_parse' AS match_method
    FROM RAW_PRODUCTS p
    WHERE p.product_id NOT IN (
        SELECT product_id FROM keyword_matches WHERE match_rank = 1
    )
    AND p.product_id NOT IN (
        SELECT product_id FROM regex_matches WHERE regex_category IS NOT NULL
    )
    AND p.raw_category_string IS NOT NULL
),

combined AS (
    SELECT product_id, mapped_category AS predicted_category, mapped_subcategory AS predicted_subcategory, match_method
    FROM keyword_matches
    WHERE match_rank = 1

    UNION ALL

    SELECT product_id, regex_category, NULL, match_method
    FROM regex_matches
    WHERE regex_category IS NOT NULL

    UNION ALL

    SELECT product_id, parsed_category, NULL, match_method
    FROM raw_category_parse
    WHERE parsed_category IS NOT NULL
)
SELECT
    product_id,
    predicted_category,
    predicted_subcategory,
    match_method
FROM combined
QUALIFY ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY
    CASE match_method
        WHEN 'keyword_lookup'     THEN 1
        WHEN 'regex_pattern'      THEN 2
        WHEN 'raw_category_parse' THEN 3
        ELSE 4
    END
) = 1;
