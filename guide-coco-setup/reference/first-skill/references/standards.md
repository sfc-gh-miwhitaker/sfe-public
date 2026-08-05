# Team Standards Reference

> **This is a template.** Replace all `{PLACEHOLDER}` values with your team's conventions before deploying. Search for `{` to find all placeholders.

## SQL Standards

### Explicit Columns Only
- **Never use SELECT \*** in production or demo code
- Always project the specific columns needed
- Exception: `SELECT *` is acceptable in ad-hoc exploration during a conversation, but never in saved SQL files

### Sargable Predicates
- Never wrap columns in functions in WHERE clauses
- Wrong: `WHERE YEAR(order_date) = 2024`
- Right: `WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'`

### QUALIFY Over Subqueries
- Use QUALIFY for window function filtering instead of wrapping in a subquery
- Wrong: `SELECT * FROM (SELECT *, ROW_NUMBER() OVER (...) AS rn FROM t) WHERE rn = 1`
- Right: `SELECT ... FROM t QUALIFY ROW_NUMBER() OVER (...) = 1`

### Join Hygiene
- Join keys must have matching types -- no implicit casts
- No OR in join predicates -- use UNION ALL with deduplication instead

## Security Rules

- **Never commit** credentials, API keys, `.env` files, or account identifiers
- Use Snowflake secrets or environment variables for all credentials
- Never include account IDs, org names, or customer names in code or output
- Global gitignore only -- never commit `.gitignore` files to repos

## Naming Conventions

> **Define your team's prefix.** Replace `{TEAM_PREFIX}` with your team or org abbreviation (e.g., `ACME`, `DS`, `FINANCE`). Replace `{DEFAULT_DB}` with your shared database name.

| Object | Pattern | Your Example |
|--------|---------|--------------|
| Database | `{DEFAULT_DB}` | _(e.g., `ANALYTICS`, `DATA_WAREHOUSE`)_ |
| Schema | `{PROJECT_NAME}` | _(e.g., `SALES_PIPELINE`)_ |
| Warehouse | `{TEAM_PREFIX}_{PROJECT}_WH` | _(e.g., `ACME_SALES_WH`)_ |
| Table (raw) | `RAW_{entity}` | `RAW_ORDERS` |
| Table (staging) | `STG_{entity}` | `STG_ORDERS` |
| Table (curated) | `{entity}` | `ORDERS` |
| Semantic View | `SV_{domain}_{entity}` | `SV_SALES_ORDERS` |

### Placeholder Reference

| Placeholder | Description | Your Value |
|-------------|-------------|------------|
| `{TEAM_PREFIX}` | Short team/org identifier (3-6 chars) | ________________ |
| `{DEFAULT_DB}` | Shared database for your team's objects | ________________ |
| `{PROJECT_NAME}` | Current project name (used as schema) | ________________ |

All objects should include a COMMENT describing their purpose.

## Attribution

> **Customize your attribution line.** Replace the example below with your team's preferred attribution format.

- Author line: `{YOUR_ATTRIBUTION}` _(e.g., `Built with Cortex Code`, `Data Team + AI`, or omit entirely)_
- No customer names or meeting references in code
