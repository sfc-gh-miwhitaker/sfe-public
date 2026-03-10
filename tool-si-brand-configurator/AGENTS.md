# Snowflake Intelligence Brand Configurator

Streamlit in Snowflake tool that extracts brand signals from a customer website,
analyzes them with Cortex COMPLETE, and generates a deployable branded SI agent.

## Project Structure
- `deploy.sql` -- Single entry point (Run All in Snowsight)
- `teardown.sql` -- Complete cleanup including EAI and network rule
- `streamlit_app.py` -- Standalone reference of the embedded Streamlit code
- `diagrams/` -- Architecture diagrams (Mermaid)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: SFE_SI_BRAND_CONFIGURATOR
- Warehouse: SFE_SI_BRAND_CONFIGURATOR_WH
- Network Rule: SFE_BRAND_SCRAPER_RULE (EGRESS, HOST_PORT)
- EAI: SFE_BRAND_SCRAPER_EAI
- Streamlit: SFE_SI_BRAND_CONFIGURATOR

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy.sql
- Agent generation: Use CREATE AGENT DDL with YAML specification
- LLM calls: Use SNOWFLAKE.CORTEX.COMPLETE for brand analysis
- String safety: No `\n` escape sequences in embedded code; use `chr(10)` / `chr(34)` / `chr(36)`

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- All new objects need COMMENT = 'DEMO: ... (Expires: 2026-06-10)'
- The Streamlit app code lives in TWO places: `streamlit_app.py` (reference) and embedded in `deploy.sql`
- Any change to the app must be synced to BOTH files
- The embedded code is inside a Python `'''` triple-quote; avoid `'''` and `\n` in string literals
- Use `chr(10)` for newlines, `chr(34)` for double quotes, `chr(36)` for dollar signs
- The helper procedure `SFE_ADD_SCRAPER_DOMAIN` runs as OWNER (SYSADMIN) to ALTER the network rule
- Generated SQL output is self-contained -- no dependencies on the configurator tool
- The SEMANTIC_MODELS schema is shared across demos; do not drop it in teardown
