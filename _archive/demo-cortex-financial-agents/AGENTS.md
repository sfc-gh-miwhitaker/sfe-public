# Cortex Financial Agents

Conversational agent for specialty finance portfolio risk assessment -- unifying structured facility/covenant data with unstructured credit memos and legal documents via Cortex Analyst + Cortex Search.

## Project Structure
- `deploy_all.sql` -- Single entry point (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered)
- `documents/` -- 40 PDF financial documents (credit memos, compliance certs, appraisals, etc.)
- `scripts/generate_pdfs.py` -- Local helper to regenerate PDFs from SQL content
- `.claude/skills/` -- Project-specific AI skill

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: FINANCIAL_AGENTS
- Warehouse: SFE_FINANCIAL_AGENTS_WH
- Stage: DOC_STAGE (internal, SSE encrypted, directory table)
- Semantic View: SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_FINANCIAL_PORTFOLIO
- Cortex Search: FACILITY_DOCUMENT_SEARCH
- Agent: PORTFOLIO_RISK_AGENT

## Key Patterns
- Dual-tool Intelligence agent (Cortex Analyst for structured data + Cortex Search for RAG)
- Specialty finance domain: facilities, covenants, credit memos, collateral appraisals
- Synthetic data -- all borrowers, facilities, and documents are fictional
- Real PDF documents staged in @DOC_STAGE with GET_PRESIGNED_URL for clickable citations
- Cortex Search with doc_type filtering and citation support (title_column = source_url for PDF links)

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
- Naming: SFE_ prefix for account-level objects only; project objects scoped by schema

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql as the single entry point
- All new objects need COMMENT = 'DEMO: ... (Expires: 2026-04-09)'
- Use specialty finance terminology: "facilities" not "loans", "borrowers" are companies not individuals
- Document types: credit_committee_memo, covenant_compliance_certificate, collateral_appraisal, amendment_letter, annual_review, borrower_financial_analysis

## Helping New Users

If the user seems confused, asks basic questions like "what is this" or "how do I start", or appears unfamiliar with the tools:

1. **Greet them warmly** and explain what this project does in one plain-English sentence
2. **Check deployment status** -- ask if they've run `deploy_all.sql` in Snowsight yet
3. **Guide step-by-step** -- if not deployed, walk them through:
   - Opening Snowsight (the Snowflake web interface)
   - Creating a new SQL worksheet
   - Pasting the contents of `deploy_all.sql`
   - Clicking "Run All" (the play button with two arrows)
4. **Suggest what to try** -- after deployment, give 2-3 specific things they can do

**Assume no technical background.** Define terms when you use them. "Snowsight is the Snowflake web interface where you run SQL" is better than just "run this in Snowsight."

## Related Projects
- [`guide-cortex-search`](../guide-cortex-search/) -- Cortex Search automation patterns (search service management and testing)
- [`guide-api-agent-context`](../guide-api-agent-context/) -- Agent Run API patterns with three auth methods
- [`demo-agent-multicontext`](../demo-agent-multicontext/) -- Per-request context injection for multi-tenant agents
- [`tool-agent-config-diff`](../tool-agent-config-diff/) -- Extract agent specs for version control
