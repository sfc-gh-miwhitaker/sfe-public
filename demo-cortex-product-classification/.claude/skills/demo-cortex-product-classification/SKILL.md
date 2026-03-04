---
name: demo-cortex-product-classification
description: "Four classification approaches for multilingual product catalogs. Triggers: product classification, glaze and classify, bakery catalog, multilingual classification, SQL keyword classification, cortex AI classification, SPCS vision model, image classification, semantic view agent, classification comparison."
---

# Glaze & Classify: Product Classification Showdown

## Purpose

Four progressively sophisticated approaches to classifying an international bakery catalog across 6 markets and 5+ languages: SQL keyword matching, simple Cortex AI, robust Cortex pipeline, and SPCS vision model for image-only products. Includes a semantic view + Intelligence agent for natural language querying and a Streamlit comparison dashboard.

## When to Use

- Adding a new classification approach or improving an existing one
- Extending the product catalog (new markets, languages, categories)
- Working with the semantic view or Intelligence agent
- Modifying the SPCS image classification service

## Architecture

```
RAW_PRODUCTS (200 products, 6 markets, 5+ languages)
RAW_CATEGORY_TAXONOMY + RAW_KEYWORD_MAP
       │
       ├── Approach 1: SQL Keyword (CASE/LIKE/regex + keyword lookup)
       │   └── STG_CLASSIFIED_TRADITIONAL
       │
       ├── Approach 2: Simple Cortex (single AI_COMPLETE + LATERAL)
       │   └── STG_CLASSIFIED_SIMPLE
       │
       ├── Approach 3: Robust Pipeline (multi-step AI_COMPLETE)
       │   └── STG_CLASSIFIED_ROBUST (taxonomy context, JSON output, confidence, language)
       │
       └── Approach 4: SPCS Vision (HTTP image classifier)
           └── STG_CLASSIFIED_VISION
                │
                ▼
       CLASSIFICATION_COMPARISON view + ACCURACY_SUMMARY
       SV_GLAZE_PRODUCTS semantic view
       GLAZE_CLASSIFIER_AGENT (cortex_analyst + data_to_chart)
       Streamlit dashboard
```

## Key Files

| File | Purpose |
|------|---------|
| `sql/02_data/02_load_sample_data.sql` | 200 products across 6 markets, multilingual |
| `sql/03_classification/01_traditional_sql.sql` | SQL keyword + regex + 3-tier fallback |
| `sql/03_classification/02_cortex_simple.sql` | Single AI_COMPLETE with LATERAL |
| `sql/03_classification/03_cortex_robust.sql` | Multi-step pipeline with structured JSON |
| `sql/03_classification/04_comparison_view.sql` | Cross-approach accuracy comparison |
| `sql/04_cortex/01_create_semantic_view.sql` | SV_GLAZE_PRODUCTS semantic view |
| `sql/04_cortex/02_create_agent.sql` | Intelligence agent with analyst + chart tools |
| `sql/05_spcs/01_create_image_service.sql` | SPCS container service + UDF |
| `streamlit/streamlit_app.py` | KPI cards, accuracy by market, live classify |

## Four Approaches Compared

| Approach | Accuracy | Multilingual | Cost | Image Support |
|----------|----------|-------------|------|---------------|
| SQL Keyword | Low | No (English keywords) | Zero | No |
| Simple Cortex | Medium | Yes (LLM native) | Low | No |
| Robust Pipeline | High | Yes + detection | Medium | No |
| SPCS Vision | Variable | N/A (image-based) | High (container) | Yes |

## Extension Playbook: Adding a New Classification Approach

1. Create `sql/03_classification/0N_<approach>.sql` following the numbered pattern
2. Create `STG_CLASSIFIED_<APPROACH>` table with columns: `PRODUCT_ID`, `PREDICTED_CATEGORY`, `CONFIDENCE`, `METHOD`
3. Add the new approach to `CLASSIFICATION_COMPARISON` view in `04_comparison_view.sql`
4. Add a section in the Streamlit dashboard
5. Update the semantic view if new metrics are needed

## Extension Playbook: Adding a New Market

1. Add products to `sql/02_data/02_load_sample_data.sql` with the new market code and language
2. Add market-specific keywords to `RAW_KEYWORD_MAP` (for Approach 1)
3. The Cortex approaches handle new languages automatically
4. Verify accuracy via `ACCURACY_SUMMARY` view

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY` |
| Warehouse | `SFE_GLAZE_AND_CLASSIFY_WH` |
| Tables | `RAW_PRODUCTS`, `RAW_CATEGORY_TAXONOMY`, `RAW_KEYWORD_MAP`, 4 `STG_CLASSIFIED_*` |
| Views | `CLASSIFICATION_COMPARISON`, `ACCURACY_SUMMARY` |
| Semantic View | `SEMANTIC_MODELS.SV_GLAZE_PRODUCTS` |
| Agent | `GLAZE_CLASSIFIER_AGENT` |
| SPCS | `IMAGE_CLASSIFIER_SERVICE`, `CLASSIFY_IMAGE` function |
| Streamlit | In-schema dashboard |

## Gotchas

- SPCS deployment is wrapped in BEGIN/EXCEPTION -- fails gracefully if compute pools unavailable
- Semantic view lives in `SEMANTIC_MODELS` schema, not the project schema
- Agent uses `cortex_analyst_text_to_sql` + `data_to_chart` (two tools)
- Robust pipeline uses `AI_COMPLETE` with structured JSON output parsing via `TRY_PARSE_JSON`
- Image classification service is a simple Python HTTP server, not a GPU model
- `deploy_all.sql` uses EXECUTE IMMEDIATE FROM (Git-integrated, not monolithic)
