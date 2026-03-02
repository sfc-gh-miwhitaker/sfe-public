/*==============================================================================
DATA MODEL - Glaze & Classify
Tables for international bakery product catalog and classification results.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

-- Core product catalog: international bakery items across 6 markets
CREATE OR REPLACE TABLE RAW_PRODUCTS (
    product_id          NUMBER AUTOINCREMENT,
    product_name        VARCHAR(500)    NOT NULL,
    product_description VARCHAR(2000),
    market_code         VARCHAR(5)      NOT NULL,
    language_code       VARCHAR(5)      NOT NULL,
    image_url           VARCHAR(1000),
    raw_category_string VARCHAR(500),
    price_local         NUMBER(10,2),
    currency_code       VARCHAR(3),
    is_seasonal         BOOLEAN         DEFAULT FALSE,
    is_active           BOOLEAN         DEFAULT TRUE,
    gold_category       VARCHAR(100),
    gold_subcategory    VARCHAR(100),
    created_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: International bakery product catalog — 6 markets, 5+ languages (Expires: 2026-03-20)';

-- Gold-standard category hierarchy
CREATE OR REPLACE TABLE RAW_CATEGORY_TAXONOMY (
    category_id     NUMBER AUTOINCREMENT,
    category        VARCHAR(100)    NOT NULL,
    subcategory     VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    sort_order      NUMBER
) COMMENT = 'DEMO: Canonical category hierarchy for classification accuracy measurement (Expires: 2026-03-20)';

-- Keyword-to-category lookup for traditional SQL classification
CREATE OR REPLACE TABLE RAW_KEYWORD_MAP (
    keyword_id      NUMBER AUTOINCREMENT,
    keyword         VARCHAR(200)    NOT NULL,
    language_code   VARCHAR(5)      DEFAULT 'en',
    mapped_category VARCHAR(100)    NOT NULL,
    mapped_subcategory VARCHAR(100),
    priority        NUMBER          DEFAULT 100
) COMMENT = 'DEMO: Keyword lookup table for SQL-based classification (Expires: 2026-03-20)';

-- Classification results: traditional SQL approach
CREATE OR REPLACE TABLE STG_CLASSIFIED_TRADITIONAL (
    product_id          NUMBER          NOT NULL,
    predicted_category  VARCHAR(100),
    predicted_subcategory VARCHAR(100),
    match_method        VARCHAR(50),
    classified_at       TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: Traditional SQL classification results (Expires: 2026-03-20)';

-- Classification results: simple Cortex COMPLETE
CREATE OR REPLACE TABLE STG_CLASSIFIED_CORTEX_SIMPLE (
    product_id          NUMBER          NOT NULL,
    predicted_category  VARCHAR(100),
    predicted_subcategory VARCHAR(100),
    raw_response        VARCHAR(5000),
    model_used          VARCHAR(100),
    classified_at       TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: Simple Cortex AI_COMPLETE classification results (Expires: 2026-03-20)';

-- Classification results: robust Cortex pipeline
CREATE OR REPLACE TABLE STG_CLASSIFIED_CORTEX_ROBUST (
    product_id          NUMBER          NOT NULL,
    detected_language   VARCHAR(50),
    predicted_category  VARCHAR(100),
    predicted_subcategory VARCHAR(100),
    confidence_score    NUMBER(5,4),
    attributes          VARIANT,
    raw_response        VARCHAR(5000),
    model_used          VARCHAR(100),
    classified_at       TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: Robust Cortex pipeline classification results (Expires: 2026-03-20)';

-- Classification results: SPCS vision model
CREATE OR REPLACE TABLE STG_CLASSIFIED_VISION (
    product_id          NUMBER          NOT NULL,
    predicted_category  VARCHAR(100),
    predicted_subcategory VARCHAR(100),
    confidence_score    NUMBER(5,4),
    raw_response        VARCHAR(5000),
    classified_at       TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: SPCS vision model classification results (Expires: 2026-03-20)';
