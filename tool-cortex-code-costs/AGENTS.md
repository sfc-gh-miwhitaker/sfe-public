# tool-cortex-code-costs — Project Instructions

<!-- Global rules apply via ~/.claude/CLAUDE.md. This file covers project-specific context only. -->

## Architecture

- `notebook.ipynb` — Snowflake Notebook with 8 SQL cells querying `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY`
- `streamlit_app.py` — Streamlit in Snowflake app; uses `get_active_session()`, no warehouse setup required
- No Snowflake objects to deploy — reads from ACCOUNT_USAGE directly

## Conventions

- Notebook cells use `%%sql -r <var>` magic (Snowflake Notebook SQL cell syntax)
- Streamlit connects via `snowflake.snowpark.context.get_active_session()`
- AI credit price default: $2.00/credit (global on demand, Table 2b of consumption table)
- Dollar cost = `TOKEN_CREDITS * ai_credit_price`
- Model pricing reference: Table 6(e) of Snowflake Service Consumption Table (April 1, 2026)

## Key Commands

```bash
# Deploy notebook to Snowflake (run from Snowsight UI — import notebook.ipynb)
# Deploy Streamlit (run from Snowsight UI — create Streamlit in Snowflake, paste streamlit_app.py)
```

## Required Privilege

```sql
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;
```
