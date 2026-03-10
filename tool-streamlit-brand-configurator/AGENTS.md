# Streamlit Brand Configurator

Visual theme builder for Streamlit in Snowflake apps. Users configure colors, fonts, borders, and logos, then export a ready-to-use `.streamlit/config.toml` and boilerplate Python code.

## Project Structure
- `deploy.sql` -- Single entry point (Run All in Snowsight)
- `teardown.sql` -- Complete cleanup
- `streamlit_app.py` -- Standalone reference copy of the app code (canonical version is embedded in deploy.sql)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: SFE_BRAND_CONFIGURATOR
- Warehouse: SFE_TOOLS_WH

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy.sql
- Python: No data persistence needed; all state lives in Streamlit session

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- The Streamlit app is embedded as a triple-single-quoted string inside a stored procedure in deploy.sql
- Avoid `\n` escape sequences inside the embedded code; use `chr(10)` or string concatenation instead
- Use single-quoted Python strings containing double quotes (not escaped double quotes) to avoid triple-quote conflicts
- All new objects need COMMENT = 'TOOL: ... (Expires: YYYY-MM-DD)'
- Keep `streamlit_app.py` in sync with the embedded version in deploy.sql

## Helping New Users

If the user seems confused, asks basic questions like "what is this" or "how do I start", or appears unfamiliar with the tools:

1. **Greet them warmly** and explain what this project does in one plain-English sentence
2. **Check deployment status** -- ask if they've run `deploy.sql` in Snowsight yet
3. **Guide step-by-step** -- if not deployed, walk them through:
   - Opening Snowsight (the Snowflake web interface)
   - Creating a new SQL worksheet
   - Pasting the contents of `deploy.sql`
   - Clicking "Run All" (the play button with two arrows)
4. **Suggest what to try** -- after deployment, navigate to Projects > Streamlit > SFE_BRAND_CONFIGURATOR

**Assume no technical background.** Define terms when you use them.
