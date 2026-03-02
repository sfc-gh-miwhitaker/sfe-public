/*==============================================================================
CLASSIFICATION COMPARISON VIEW
Side-by-side results from all four approaches for accuracy analysis.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

CREATE OR REPLACE VIEW CLASSIFICATION_COMPARISON
  COMMENT = 'DEMO: Side-by-side classification accuracy across all four approaches (Expires: 2026-03-20)'
AS
SELECT
    p.product_id,
    p.product_name,
    p.market_code,
    p.language_code,
    p.gold_category,
    p.gold_subcategory,

    -- Approach 1: Traditional SQL
    t.predicted_category        AS trad_category,
    t.predicted_subcategory     AS trad_subcategory,
    t.match_method              AS trad_method,
    CASE WHEN t.predicted_category = p.gold_category THEN 1 ELSE 0 END
                                AS trad_category_correct,
    CASE WHEN t.predicted_category = p.gold_category
              AND COALESCE(t.predicted_subcategory, '') = COALESCE(p.gold_subcategory, '')
         THEN 1 ELSE 0 END     AS trad_full_correct,

    -- Approach 2: Cortex Simple
    cs.predicted_category       AS simple_category,
    cs.predicted_subcategory    AS simple_subcategory,
    CASE WHEN cs.predicted_category = p.gold_category THEN 1 ELSE 0 END
                                AS simple_category_correct,
    CASE WHEN cs.predicted_category = p.gold_category
              AND COALESCE(cs.predicted_subcategory, '') = COALESCE(p.gold_subcategory, '')
         THEN 1 ELSE 0 END     AS simple_full_correct,

    -- Approach 3: Cortex Robust
    cr.detected_language        AS robust_detected_lang,
    cr.predicted_category       AS robust_category,
    cr.predicted_subcategory    AS robust_subcategory,
    cr.confidence_score         AS robust_confidence,
    cr.attributes               AS robust_attributes,
    CASE WHEN cr.predicted_category = p.gold_category THEN 1 ELSE 0 END
                                AS robust_category_correct,
    CASE WHEN cr.predicted_category = p.gold_category
              AND COALESCE(cr.predicted_subcategory, '') = COALESCE(p.gold_subcategory, '')
         THEN 1 ELSE 0 END     AS robust_full_correct,

    -- Approach 4: SPCS Vision (populated after SPCS deployment)
    v.predicted_category        AS vision_category,
    v.predicted_subcategory     AS vision_subcategory,
    v.confidence_score          AS vision_confidence,
    CASE WHEN v.predicted_category = p.gold_category THEN 1 ELSE 0 END
                                AS vision_category_correct,
    CASE WHEN v.predicted_category = p.gold_category
              AND COALESCE(v.predicted_subcategory, '') = COALESCE(p.gold_subcategory, '')
         THEN 1 ELSE 0 END     AS vision_full_correct,

    -- Metadata
    p.product_description IS NULL AND p.product_name LIKE 'IMG_%'
                                AS is_image_only,
    p.image_url,
    p.is_seasonal

FROM RAW_PRODUCTS p
LEFT JOIN STG_CLASSIFIED_TRADITIONAL t
    ON p.product_id = t.product_id
LEFT JOIN STG_CLASSIFIED_CORTEX_SIMPLE cs
    ON p.product_id = cs.product_id
LEFT JOIN STG_CLASSIFIED_CORTEX_ROBUST cr
    ON p.product_id = cr.product_id
LEFT JOIN STG_CLASSIFIED_VISION v
    ON p.product_id = v.product_id;

-- Accuracy summary view for quick dashboard access
CREATE OR REPLACE VIEW ACCURACY_SUMMARY
  COMMENT = 'DEMO: Aggregated accuracy metrics by approach and market (Expires: 2026-03-20)'
AS
SELECT
    market_code,
    language_code,
    COUNT(*)                                            AS total_products,
    SUM(trad_category_correct)                          AS trad_correct,
    ROUND(AVG(trad_category_correct) * 100, 1)          AS trad_accuracy_pct,
    SUM(simple_category_correct)                        AS simple_correct,
    ROUND(AVG(simple_category_correct) * 100, 1)        AS simple_accuracy_pct,
    SUM(robust_category_correct)                        AS robust_correct,
    ROUND(AVG(robust_category_correct) * 100, 1)        AS robust_accuracy_pct,
    SUM(vision_category_correct)                        AS vision_correct,
    ROUND(AVG(vision_category_correct) * 100, 1)        AS vision_accuracy_pct,
    ROUND(AVG(robust_confidence), 3)                    AS avg_robust_confidence
FROM CLASSIFICATION_COMPARISON
GROUP BY market_code, language_code;
