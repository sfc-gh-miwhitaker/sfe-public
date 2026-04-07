# tool-cortex-code-costs — Project Instructions

<!-- Global rules apply via ~/.claude/CLAUDE.md. This file covers project-specific context only. -->

## Architecture

- `notebook.ipynb` — Snowflake Notebook with 9 Python cells; `source` variable selects CLI / Snowsight / both (default: both)
- `streamlit_app.py` — Streamlit in Snowflake app; sidebar "Data Source" radio picks CLI / Snowsight / Combined
- `deploy_all.sql` — one-shot Snowsight deploy script (Git-based); creates schema, notebook, and Streamlit app
- No Snowflake objects beyond the schema/notebook/Streamlit — reads ACCOUNT_USAGE directly

## Data Sources

- `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY` — terminal / `snow` CLI usage
- `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` — browser IDE (Snowsight) usage
- Schemas are identical: USER_ID, REQUEST_ID, USAGE_TIME, TOKEN_CREDITS, TOKENS, CREDITS_GRANULAR (OBJECT), TOKENS_GRANULAR (OBJECT)

## Conventions

- Notebook cells use `%%sql -r <var>` magic (Snowflake Notebook SQL cell syntax)
- Streamlit connects via `snowflake.snowpark.context.get_active_session()`
- AI credit price default: $2.00/credit (global on demand, Table 2b of consumption table)
- Dollar cost = `TOKEN_CREDITS * ai_credit_price`
- Model pricing reference: Table 6(e) of Snowflake Service Consumption Table (April 1, 2026)

## Key Commands

```bash
# One-shot deploy (Snowsight): paste deploy_all.sql → Run All
# Manual notebook deploy: Snowsight > Projects > Notebooks > + > Import .ipynb
# Manual Streamlit deploy: Snowsight > Projects > Streamlit > + > paste streamlit_app.py
```

## Required Privilege

```sql
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;
```
