![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--05--01-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# API Data Fetcher

> DEMONSTRATION PROJECT - EXPIRES: 2026-05-01
> This tool uses Snowflake features current as of March 2026.
> **No support provided.** This code is for reference only. Review, test, and modify before any production use.

A Python stored procedure that fetches data from a public REST API and stores it in a Snowflake table, demonstrating External Access Integration.

---

## What It Does

- Fetches user data from JSONPlaceholder public API
- Parses JSON response and extracts relevant fields
- Stores data in a Snowflake table
- Returns the fetched data as a result set

---

## Snowflake Features Demonstrated

- **External Access Integration** - Secure outbound network access
- **Network Rules** - Define allowed egress destinations
- **Python Stored Procedures** - Server-side Python execution
- **Snowpark** - DataFrame operations for data manipulation

---

## Quick Start

**Deploy in Snowsight (no clone needed):**
Copy [`deploy.sql`](deploy.sql) into a Snowsight worksheet and click **Run All**.

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) tool-api-data-fetcher
cd sfe-public/tool-api-data-fetcher && cortex
```

### Use the Tool

```sql
-- Fetch data from API
CALL SNOWFLAKE_EXAMPLE.SFE_API_FETCHER.SFE_FETCH_USERS();

-- View the fetched data
SELECT * FROM SNOWFLAKE_EXAMPLE.SFE_API_FETCHER.SFE_USERS;
```

---

## Objects Created

| Object Type | Name | Purpose |
|-------------|------|---------|
| Schema | `SNOWFLAKE_EXAMPLE.SFE_API_FETCHER` | Tool namespace |
| Table | `SFE_USERS` | Stores fetched user data |
| Network Rule | `SFE_API_NETWORK_RULE` | Allows egress to API |
| Integration | `SFE_API_ACCESS` | External access integration |
| Procedure | `SFE_FETCH_USERS` | Fetches and stores data |

---

## API Details

**Endpoint:** `https://jsonplaceholder.typicode.com/users`

This is a free, public fake REST API for testing and prototyping. No authentication required.

**Response Fields Used:**
- `id` → `user_id`
- `name` → `name`
- `username` → `username`
- `email` → `email`
- `phone` → `phone`
- `website` → `website`
- `company.name` → `company_name`
- `address.city` → `city`

---

## Sample Data

After calling the procedure:

```sql
SELECT user_id, name, email, company_name
FROM SNOWFLAKE_EXAMPLE.SFE_API_FETCHER.SFE_USERS
LIMIT 3;
```

| user_id | name | email | company_name |
|---------|------|-------|--------------|
| 1 | Leanne Graham | Sincere@april.biz | Romaguera-Crona |
| 2 | Ervin Howell | Shanna@melissa.tv | Deckow-Crist |
| 3 | Clementine Bauch | Nathan@yesenia.net | Romaguera-Jacobson |

---

## Cleanup

```sql
-- Copy teardown.sql into Snowsight, Run All
```

This removes:
- Schema `SFE_API_FETCHER` and all contained objects
- External Access Integration `SFE_API_ACCESS`
- Network Rule
- Does NOT remove shared infrastructure (database, warehouse)

---

## Architecture

See `diagrams/` for:
- `data-flow.md` - How API data flows into Snowflake
- `network-flow.md` - Network architecture for external access

---

## Customization Ideas

1. **Different API** - Modify for any public REST API
2. **Add scheduling** - Create a Task to fetch data periodically
3. **Add authentication** - Use Snowflake Secrets for API keys
4. **Add error handling** - Retry logic, dead-letter table

---

## How External Access Works

```
┌─────────────────────────────────────────────────────────────┐
│ Snowflake Account                                           │
│                                                             │
│  ┌──────────────────┐    ┌─────────────────────────────┐   │
│  │ Stored Procedure │───>│ External Access Integration │   │
│  │ (Python)         │    │ (SFE_API_ACCESS)            │   │
│  └──────────────────┘    └──────────────┬──────────────┘   │
│                                         │                   │
│                          ┌──────────────▼──────────────┐   │
│                          │ Network Rule                │   │
│                          │ (SFE_API_NETWORK_RULE)      │   │
│                          │ EGRESS: typicode.com:443    │   │
│                          └──────────────┬──────────────┘   │
└─────────────────────────────────────────┼───────────────────┘
                                          │
                                          ▼ HTTPS
                          ┌───────────────────────────────┐
                          │ JSONPlaceholder API           │
                          │ jsonplaceholder.typicode.com  │
                          └───────────────────────────────┘
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `SFE_FETCH_USERS` fails | Verify External Access Integration exists: `SHOW INTEGRATIONS`. Ensure ACCOUNTADMIN role was used for deploy. |
| Empty table after CALL | Check network rule allows egress to `jsonplaceholder.typicode.com`. |
| Permission denied on integration | External Access Integrations require ACCOUNTADMIN to create. |

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skills (Cursor + Claude Code)
- **Cortex Code in Snowsight** -- Open this project in a Workspace for AI-assisted development
- **Cursor** -- Open locally with Cursor for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)

---

*SE Community • API Data Fetcher Tool • Last Updated: 2026-03-02*
