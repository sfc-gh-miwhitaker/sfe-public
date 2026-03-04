![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--05--01-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Glaze & Classify

> **Warning:** This demo expires on 2026-05-01. After expiration, validate against current Snowflake docs before use.
> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

Product classification showdown: four progressively sophisticated approaches to classifying an international bakery catalog — from brittle SQL to robust Cortex AI pipelines and custom SPCS vision models.

**Author:** SE Community
**Last Updated:** 2026-03-02 | **Expires:** 2026-05-01 | **Status:** ACTIVE

## Quick Start

**Deploy in Snowsight (no clone needed):**
Copy [`deploy_all.sql`](deploy_all.sql) into a Snowsight worksheet and click **Run All**.

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) demo-cortex-product-classification
cd sfe-public/demo-cortex-product-classification && cortex
```

## First Time Here?

1. **Deploy** — Copy `deploy_all.sql` into Snowsight, click "Run All"
2. **Explore** — Open the Streamlit dashboard to compare classification methods side-by-side
3. **Ask** — Chat with the Intelligence agent about classification accuracy across markets
4. **Cleanup** — Run `teardown_all.sql` when done

## What Gets Built

| Object | Type | Purpose |
|--------|------|---------|
| `SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY` | Schema | Project schema |
| `SFE_GLAZE_AND_CLASSIFY_WH` | Warehouse | XS compute |
| `RAW_PRODUCTS` | Table | International product catalog (6 markets, 5+ languages) |
| `RAW_CATEGORY_TAXONOMY` | Table | Gold-standard category hierarchy |
| `RAW_KEYWORD_MAP` | Table | Traditional keyword-to-category lookup |
| `STG_CLASSIFIED_TRADITIONAL` | Table | SQL-based classification results |
| `STG_CLASSIFIED_CORTEX_SIMPLE` | Table | Simple Cortex COMPLETE results |
| `STG_CLASSIFIED_CORTEX_ROBUST` | Table | Robust Cortex pipeline results |
| `STG_CLASSIFIED_VISION` | Table | SPCS image classifier results |
| `CLASSIFICATION_COMPARISON` | View | Side-by-side accuracy comparison |
| `SV_GLAZE_PRODUCTS` | Semantic View | Intelligence agent data layer |
| `GLAZE_CLASSIFIER_AGENT` | Agent | Conversational product analysis |
| `GLAZE_CLASSIFY_DASHBOARD` | Streamlit | Interactive comparison dashboard |
| `GLAZE_VISION_SERVICE` | SPCS Service | Custom image classification model |

## The Four Approaches

### 1. Traditional SQL (Baseline)
CASE/LIKE/regex with keyword lookup tables. Works for English, breaks on Japanese katakana, fails entirely on image-only products. Requires constant maintenance as the catalog grows.

### 2. Cortex COMPLETE — Simple
A single `AI_COMPLETE()` call with a classification prompt. ~10 lines of SQL. Handles multiple languages out of the box. Shows how fast you can get started with AI classification.

### 3. Cortex COMPLETE — Robust
Multi-step pipeline: language detection, structured JSON output via type literals, hierarchical classification (Category > Subcategory > Attributes), confidence scoring, batch processing with error handling. Robust reference pattern.

### 4. SPCS Custom Vision Model
Snowpark Container Services running a lightweight image classification model. Exposed as a SQL-callable service function. Shows "bring your own model" for specialized domains where general LLMs fall short.

## Architecture

```mermaid
flowchart LR
    subgraph data [Raw Data]
        Products[RAW_PRODUCTS]
    end

    subgraph traditional [Traditional SQL]
        Keywords[RAW_KEYWORD_MAP]
        CaseLogic[CASE/LIKE/Regex]
    end

    subgraph cortexSimple [Cortex Simple]
        Complete1[AI_COMPLETE]
    end

    subgraph cortexRobust [Cortex Robust]
        LangDetect[Language Detection]
        StructOut[Structured Output]
        Hierarchy[Hierarchical Classification]
    end

    subgraph spcsVision [SPCS Vision]
        Container[Image Classifier]
        ServiceFn[Service Function]
    end

    Products --> CaseLogic
    Keywords --> CaseLogic
    Products --> Complete1
    Products --> LangDetect --> StructOut --> Hierarchy
    Products --> Container --> ServiceFn

    CaseLogic --> Compare[CLASSIFICATION_COMPARISON]
    Complete1 --> Compare
    Hierarchy --> Compare
    ServiceFn --> Compare

    Compare --> Dashboard[Streamlit Dashboard]
    Compare --> Agent[Intelligence Agent]
```

## Estimated Demo Costs

| Component | Size | Est. Credits/Run | Notes |
|-----------|------|-----------------|-------|
| Warehouse | X-SMALL | ~0.5 | Sample data load + classification |
| Cortex AI_COMPLETE | — | ~1.0 | ~200 products x 2 approaches |
| SPCS Compute Pool | CPU_X64_XS | ~0.5 | Image classification service |
| Storage | — | Minimal | <1 MB sample data |
| **Total** | | **~2.0 credits** | Single deployment run |

**Edition Required:** Enterprise (for SPCS + Cortex)

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Cortex AI_COMPLETE unavailable | Verify your region supports Cortex AI. See [Cortex availability](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions#availability). |
| SPCS service won't start | Ensure Enterprise edition and a compute pool exists. Check `SHOW COMPUTE POOLS`. |
| Intelligence agent errors | Verify the semantic view `SV_GLAZE_PRODUCTS` exists and the warehouse is running. |
| Classification results empty | Ensure `RAW_PRODUCTS` has data. Rerun the data load step if needed. |

## Cleanup

Run `teardown_all.sql` in Snowsight to remove all demo objects.

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skills (Cursor + Claude Code)
- **Cortex Code in Snowsight** -- Open this project in a Workspace for AI-assisted development
- **Cursor** -- Open locally with Cursor for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)

## Documentation

- [Deployment Guide](docs/01-DEPLOYMENT.md)
- [Usage Guide](docs/02-USAGE.md)
- [Cleanup Guide](docs/03-CLEANUP.md)
