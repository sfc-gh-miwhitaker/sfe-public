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
RAW_DOCUMENTS ──── FACILITY_DOCUMENT_SEARCH ─┘
                   (Cortex Search RAG)
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Single entry point for Snowsight deployment |
| `sql/01_setup/01_create_schema.sql` | Schema and warehouse creation |
| `sql/02_data/01_create_tables.sql` | All table DDL |
| `sql/02_data/02-06_load_*.sql` | Synthetic data inserts (borrowers, facilities, covenants, metrics, documents) |
| `sql/03_search/01_create_search_service.sql` | Cortex Search service on RAW_DOCUMENTS |
| `sql/04_cortex/01_create_semantic_view.sql` | Semantic view across 4 structured tables |
| `sql/04_cortex/02_create_agent.sql` | Dual-tool Intelligence agent |

## Adding a New Document Type

1. Add rows to `RAW_DOCUMENTS` with a new `doc_type` value (e.g., `'workout_memo'`)
2. The Cortex Search service auto-refreshes (TARGET_LAG = 1 hour) -- no rebuild needed
3. Update the agent's `DocumentSearch` tool description in `02_create_agent.sql` to mention the new type
4. Optionally add a `doc_type` filter example in the agent's `sample_questions`

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
