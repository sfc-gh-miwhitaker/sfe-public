---
name: tool-api-data-fetcher
description: "Python stored procedure for REST API ingestion via External Access Integration. Triggers: external access integration, network rule, REST API ingestion, python stored procedure, API data fetch, external API snowflake."
---

# API Data Fetcher

## Purpose

Python stored procedure that fetches data from a public REST API and stores it in Snowflake using External Access Integration. Demonstrates the minimal pattern for network-enabled stored procedures.

## When to Use

- Setting up External Access Integration for a new API
- Writing Python stored procedures with network access
- Adapting the pattern for different REST endpoints

## Architecture

```
Public REST API (JSONPlaceholder)
       │
       ▼
Network Rule (SFE_API_NETWORK_RULE)
       │
       ▼
External Access Integration (SFE_API_ACCESS)
       │
       ▼
Python Stored Proc (Snowpark session)
       │
       ▼
SFE_USERS table (Snowpark DataFrame write)
```

## Key Files

| File | Purpose |
|------|---------|
| `deploy.sql` | Full deployment: schema, table, network rule, integration, stored proc |
| `teardown.sql` | Drops schema + integration |

## External Access Pattern

```sql
CREATE OR REPLACE NETWORK RULE <rule_name>
    TYPE = HOST_PORT MODE = EGRESS
    VALUE_LIST = ('<api_host>');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION <integration_name>
    ALLOWED_NETWORK_RULES = (<rule_name>)
    ENABLED = TRUE;

CREATE OR REPLACE PROCEDURE <proc_name>()
    RETURNS STRING LANGUAGE PYTHON RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python', 'requests')
    EXTERNAL_ACCESS_INTEGRATIONS = (<integration_name>)
    HANDLER = 'main'
AS $$ ... $$;
```

## Extension Playbook: Adding a New API Endpoint

1. Update `VALUE_LIST` in the network rule to include the new host
2. Add a new table for the fetched data
3. Add a fetch function in the stored procedure using `requests.get()`
4. Write results via `session.create_dataframe().write.save_as_table()`
5. Handle pagination if the API requires it

## Extension Playbook: Adding Authentication

1. Create a Snowflake SECRET object for API keys or OAuth tokens
2. Add `ALLOWED_AUTHENTICATION_SECRETS` to the External Access Integration
3. Access the secret in the stored procedure via `_snowflake.get_generic_secret_string()`

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.SFE_API_FETCHER` |
| Warehouse | `SFE_TOOLS_WH` (shared) |
| Table | `SFE_USERS` |
| Network Rule | `SFE_API_NETWORK_RULE` |
| Integration | `SFE_API_ACCESS` |
| Procedure | Python stored proc |

## Gotchas

- External Access Integration requires ACCOUNTADMIN to create
- Network Rule VALUE_LIST is host-only, no protocol or path
- The `requests` package must be listed in PACKAGES
- Snowpark DataFrame `write.save_as_table()` overwrites by default -- use `mode='append'` for incremental
- JSONPlaceholder is a free test API -- no auth needed for the demo
