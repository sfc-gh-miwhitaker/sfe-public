---
name: cortex-financial-agents
description: "Project-specific skill for Cortex Financial Agents demo. Dual-tool Intelligence agent combining Cortex Analyst (structured facility/covenant data) with Cortex Search RAG (credit memos, legal docs). Use when working with this project in any AI-pair tool."
---

# Cortex Financial Agents

## Purpose
Demonstrates a conversational Intelligence agent for specialty finance portfolio risk assessment, combining structured facility/covenant analytics (Cortex Analyst via semantic view) with unstructured document retrieval (Cortex Search RAG with citations).

## Architecture

```
RAW_BORROWERS ──┐
RAW_FACILITIES ─┤── SV_FINANCIAL_PORTFOLIO ──┐
RAW_COVENANTS ──┤   (Cortex Analyst)         ├── PORTFOLIO_RISK_AGENT
RAW_PORTFOLIO   ┘                            │
_METRICS                                     │
                                             │
documents/*.pdf ─── COPY FILES ─── @DOC_STAGE│
                                     │       │
RAW_DOCUMENTS ──┬── text content ────┤       │
                └── GET_PRESIGNED_URL┘       │
                    FACILITY_DOCUMENT_SEARCH ─┘
                    (Cortex Search RAG + clickable citations)
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Single entry point for Snowsight deployment |
| `sql/01_setup/01_create_schema.sql` | Schema and warehouse creation |
| `sql/02_data/01_create_tables.sql` | All table DDL |
| `sql/02_data/02-06_load_*.sql` | Synthetic data inserts (borrowers, facilities, covenants, metrics, documents) |
| `sql/02_data/07_stage_documents.sql` | Creates `@DOC_STAGE`, copies PDFs from git, enables directory table |
| `documents/*.pdf` | 40 professional PDF documents generated from synthetic content |
| `scripts/generate_pdfs.py` | Local helper to regenerate PDFs from SQL content (requires `fpdf2`) |
| `sql/03_search/01_create_search_service.sql` | Cortex Search service with `GET_PRESIGNED_URL` for clickable citations |
| `sql/04_cortex/01_create_semantic_view.sql` | Semantic view across 4 structured tables |
| `sql/04_cortex/02_create_agent.sql` | Dual-tool Intelligence agent |

## Adding a New Document Type

1. Add rows to `RAW_DOCUMENTS` with a new `doc_type` value (e.g., `'workout_memo'`)
2. Generate a matching PDF: add content to `06_load_documents.sql`, then run `python scripts/generate_pdfs.py`
3. Commit the new PDF to `documents/` so it deploys via the git stage
4. Redeploy: the `COPY FILES` step stages the new PDF and the search service auto-refreshes
5. Update the agent's `DocumentSearch` tool description in `02_create_agent.sql` to mention the new type
6. Optionally add a `doc_type` filter example in the agent's `sample_questions`

## Adding a New Structured Table

1. Create the table in `sql/02_data/01_create_tables.sql` with COMMENT including expiration
2. Add INSERT data in a new `sql/02_data/0N_load_*.sql` file
3. Add the table to the semantic view in `sql/04_cortex/01_create_semantic_view.sql`:
   - Add to TABLES section with PRIMARY KEY and SYNONYMS
   - Add RELATIONSHIPS linking to existing tables
   - Add relevant FACTS, DIMENSIONS, and METRICS
4. Add the EXECUTE IMMEDIATE FROM line to `deploy_all.sql`

## Snowflake Objects
- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `FINANCIAL_AGENTS`
- Warehouse: `SFE_FINANCIAL_AGENTS_WH`
- Tables: `RAW_BORROWERS`, `RAW_FACILITIES`, `RAW_COVENANTS`, `RAW_PORTFOLIO_METRICS`, `RAW_DOCUMENTS`
- Stage: `DOC_STAGE` (internal, SSE encrypted, directory table enabled)
- Search Service: `FACILITY_DOCUMENT_SEARCH`
- Semantic View: `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_FINANCIAL_PORTFOLIO`
- Agent: `PORTFOLIO_RISK_AGENT`
- All objects have `COMMENT = 'DEMO: ... (Expires: 2026-04-09)'`

## Gotchas
- Semantic view lives in `SEMANTIC_MODELS` schema, not `FINANCIAL_AGENTS` -- agent references the fully qualified path
- Cortex Search service needs TARGET_LAG time to index after creation; queries may return empty results for ~1 min
- Agent uses `orchestration: auto` (no pinned model) for cross-region portability
- Document `content` column must be VARCHAR, not VARIANT -- Cortex Search indexes text columns only
- Covenant `in_compliance` is BOOLEAN but the semantic view exposes it as a dimension for filtering; the agent handles the cast
- `title_column: "source_url"` in the agent spec is what makes citations clickable -- setting it to `"title"` would break citations
- `GET_PRESIGNED_URL` in the search service source query generates 7-day URLs; the hourly refresh keeps them fresh
- `@DOC_STAGE` must use `ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')` for presigned URLs to work on internal stages
- PDFs must exist in `@DOC_STAGE` BEFORE the search service is created (deploy order matters)
