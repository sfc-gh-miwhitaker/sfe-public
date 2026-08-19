![Guide](https://img.shields.io/badge/type-guide-blue)
![No Deploy](https://img.shields.io/badge/deploy-none-inactive)
![Expires](https://img.shields.io/badge/expires-2027--02--19-yellow)
![Status](https://img.shields.io/badge/status-ACTIVE-brightgreen)

# Organization Reporting in Snowflake

A primer on reporting across a multi-account Snowflake footprint using
`SNOWFLAKE.ORGANIZATION_USAGE`.

**Audience:** Snowflake administrators, FinOps engineers, and platform teams managing
multiple accounts within a single Snowflake organization.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-08-19 | **Expires:** 2027-02-19 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Start Here

If you run more than one Snowflake account, you eventually need one question answered in
one place: *what is happening across all of them?* Credits by account, storage growth,
who logged in where, which warehouses are driving spend. Snowflake exposes this through
`SNOWFLAKE.ORGANIZATION_USAGE`.

This guide covers:
1. What's in ORGANIZATION_USAGE
2. How to get access (two different paths)
3. Query discipline that keeps costs low
4. The two boundaries that surprise people

---

## Two Layers of Usage Data

Every Snowflake account has a shared, read-only database named `SNOWFLAKE`. Inside it are
two usage schemas at different scopes:

| Schema | Scope | Available in |
|--------|-------|--------------|
| `ACCOUNT_USAGE` | A single account | Every account |
| `ORGANIZATION_USAGE` | All accounts in the organization | An organization account, or a regular account with the `ORGADMIN` role enabled |

The `ORGANIZATION_USAGE` views largely mirror their `ACCOUNT_USAGE` counterparts, with
three columns added: `ORGANIZATION_NAME`, `ACCOUNT_LOCATOR`, and `ACCOUNT_NAME`. That
account dimension is the entire value — it's what turns twenty separate reports into one
grouped query.

---

## Two Access Paths

These two paths are **not** equivalent. Choosing between them is the single most important
decision to make before building anything.

### Organization Account

A dedicated account type for org-wide administration. Gets the **complete view set**,
including premium views.

- Requires Enterprise Edition or higher
- Premium views bill based on records processed
- Allow ~2 weeks after creation for 365 days of history to backfill
- By default available to organizations with a capacity contract

### ORGADMIN-Enabled Account

A normal account with the `ORGADMIN` role switched on. **No premium views.** Roughly two
dozen views covering consumption and billing.

- No extra edition requirement
- No premium-view processing charges
- Credits, cost, and storage: yes — per-query, per-user, per-object: no

### Decide This First

> **If the answer is** credits, cost, and storage by account, the `ORGADMIN` path is
> sufficient and free of premium-view charges.
>
> **If the answer includes** who ran what, who has access to what, or what the security
> posture looks like across accounts, that requires an **organization account**.

---

## What Each Path Gives You

### Non-Premium Path (ORGADMIN-Enabled Account)

**Consumption:**
`METERING_DAILY_HISTORY`, `WAREHOUSE_METERING_HISTORY`, `STORAGE_DAILY_HISTORY`,
`DATABASE_STORAGE_USAGE_HISTORY`, `STAGE_STORAGE_USAGE_HISTORY`, `DATA_TRANSFER_HISTORY`,
`DATA_TRANSFER_DAILY_HISTORY`

**Serverless features:**
`AUTOMATIC_CLUSTERING_HISTORY`, `MATERIALIZED_VIEW_REFRESH_HISTORY`,
`PIPE_USAGE_HISTORY`, `QUERY_ACCELERATION_HISTORY`, `SEARCH_OPTIMIZATION_HISTORY`,
`REPLICATION_USAGE_HISTORY`, `REPLICATION_GROUP_USAGE_HISTORY`

**Billing:**
`USAGE_IN_CURRENCY_DAILY`, `RATE_SHEET_DAILY`, `REMAINING_BALANCE_DAILY`,
`CONTRACT_ITEMS`, `ANOMALIES_IN_CURRENCY_DAILY`

**Inventory:**
`ACCOUNTS`

**Marketplace:**
`MARKETPLACE_PAID_USAGE_DAILY`, `MARKETPLACE_DISBURSEMENT_REPORT`,
`MONETIZED_USAGE_DAILY`, `LISTING_AUTO_FULFILLMENT_USAGE_HISTORY`

### Premium Path (Organization Account Only)

These are the org-level equivalents of the `ACCOUNT_USAGE` views. This is where
operational and security reporting lives.

**Query and workload:**
`QUERY_HISTORY`, `AGGREGATE_QUERY_HISTORY`, `QUERY_ATTRIBUTION_HISTORY`,
`QUERY_INSIGHTS`, `METERING_HISTORY`, `TASK_HISTORY`, `COPY_HISTORY`, `LOAD_HISTORY`,
`WAREHOUSE_LOAD_HISTORY`, `WAREHOUSE_EVENTS_HISTORY`

**Security and identity:**
`USERS`, `ROLES`, `GRANTS_TO_ROLES`, `GRANTS_TO_USERS`, `LOGIN_HISTORY`,
`SESSIONS`, `PASSWORD_POLICIES`, `SESSION_POLICIES`, `NETWORK_POLICIES`, `NETWORK_RULES`,
`TRUST_CENTER_FINDINGS`

**Governance:**
`ACCESS_HISTORY`, `MASKING_POLICIES`, `ROW_ACCESS_POLICIES`, `POLICY_REFERENCES`,
`TAGS`, `TAG_REFERENCES`, `OBJECT_DEPENDENCIES`

**Object inventory:**
`DATABASES`, `SCHEMATA`, `TABLES`, `VIEWS`, `COLUMNS`, `STAGES`, `PIPES`, `FUNCTIONS`,
`PROCEDURES`, `SHARES`, `LISTINGS`, `SEMANTIC_VIEWS`

**AI and Cortex:**
`CORTEX_AI_FUNCTIONS_USAGE_HISTORY`, `CORTEX_AGENT_USAGE_HISTORY`,
`CORTEX_SEARCH_SERVING_USAGE_HISTORY`, `CORTEX_CODE_CLI_USAGE_HISTORY`,
`CORTEX_CODE_DESKTOP_USAGE_HISTORY`, `SNOWFLAKE_COWORK_USAGE_HISTORY`

> See the [ORGANIZATION_USAGE view reference](https://docs.snowflake.com/en/sql-reference/organization-usage)
> for the full, current list of views and their latency.

---

## Granting Access

Access is granted through predefined roles, not direct `GRANT SELECT` statements.
Which kind of role depends on the path.

### In an Organization Account — Application Roles

By default only `GLOBALORGADMIN` can read these views. Grant an application role from the
`SNOWFLAKE` application to open it up:

```sql
USE ROLE GLOBALORGADMIN;

-- Full access to all ORGANIZATION_USAGE views
GRANT APPLICATION ROLE SNOWFLAKE.ORG_USAGE_ADMIN TO ROLE my_reporting_role;

-- Or scope to what the consumer actually needs
GRANT APPLICATION ROLE SNOWFLAKE.ORGANIZATION_USAGE_VIEWER      TO ROLE my_reporting_role;
GRANT APPLICATION ROLE SNOWFLAKE.ORGANIZATION_BILLING_VIEWER     TO ROLE my_reporting_role;
GRANT APPLICATION ROLE SNOWFLAKE.ORGANIZATION_SECURITY_VIEWER    TO ROLE my_reporting_role;
GRANT APPLICATION ROLE SNOWFLAKE.ORGANIZATION_GOVERNANCE_VIEWER  TO ROLE my_reporting_role;
GRANT APPLICATION ROLE SNOWFLAKE.ORGANIZATION_OBJECT_VIEWER      TO ROLE my_reporting_role;
GRANT APPLICATION ROLE SNOWFLAKE.ORGANIZATION_ACCOUNTS_VIEWER    TO ROLE my_reporting_role;

GRANT ROLE my_reporting_role TO USER reporting_service_user;
```

| Application Role | Covers |
|-----------------|--------|
| `ORGANIZATION_USAGE_VIEWER` | Metering, warehouses, storage, data transfer, serverless feature history |
| `ORGANIZATION_BILLING_VIEWER` | Currency, rate sheet, remaining balance, contract items, Marketplace disbursement |
| `ORGANIZATION_SECURITY_VIEWER` | Users, roles, grants, logins, sessions, policies, Trust Center findings |
| `ORGANIZATION_GOVERNANCE_VIEWER` | Access history, query history, masking/row-access policies, tags |
| `ORGANIZATION_OBJECT_VIEWER` | Databases, schemas, tables, views, columns, stages, pipes, procedures |
| `ORGANIZATION_ACCOUNTS_VIEWER` | The `ACCOUNTS` inventory view |

### In an ORGADMIN-Enabled Account — Database Roles

> **Common stumbling block:** In an ORGADMIN-enabled account, the shared `SNOWFLAKE`
> database is accessible to `ACCOUNTADMIN` by default — the `ORGADMIN` role itself does
> **not** have the necessary privileges. Enabling `ORGADMIN` and then querying as
> `ORGADMIN` fails until you grant it explicitly.

Three database roles carry `SELECT`:

```sql
USE ROLE ACCOUNTADMIN;

GRANT DATABASE ROLE SNOWFLAKE.ORGANIZATION_USAGE_VIEWER      TO ROLE my_reporting_role;
GRANT DATABASE ROLE SNOWFLAKE.ORGANIZATION_BILLING_VIEWER    TO ROLE my_reporting_role;
GRANT DATABASE ROLE SNOWFLAKE.ORGANIZATION_ACCOUNTS_VIEWER   TO ROLE my_reporting_role;
```

---

## Query Discipline

These views span every account in the organization, so they get large quickly. Two rules
keep them fast and cheap.

### 1. Always Bound the Time Range

Each historical view has a primary time column. An unbounded query forces Snowflake to
consider the full history across every account before it can return a single row —
including for something as innocent-looking as `SELECT COUNT(*)` or `LIMIT 1`.

| View | Primary Time Column |
|------|-------------------|
| `QUERY_HISTORY` | `start_time` |
| `METERING_HISTORY` | `start_time` |
| `QUERY_ATTRIBUTION_HISTORY` | `start_time` |
| `QUERY_INSIGHTS` | `start_time` |
| `AGGREGATE_QUERY_HISTORY` | `interval_start_time` |
| `ACCESS_HISTORY` | `query_start_time` |
| `COPY_HISTORY` / `LOAD_HISTORY` | `last_load_time` |
| `LOGIN_HISTORY` | `event_timestamp` |
| `SESSIONS` | `created_on` |
| `TASK_HISTORY` / `ALERT_HISTORY` | `scheduled_time` |
| `WAREHOUSE_EVENTS_HISTORY` | `timestamp` |
| `LOCK_WAIT_HISTORY` | `requested_at` |

When joining several views, bound **each one** separately — a predicate on one side of a
join does not constrain the scan on the other.

### 2. Never SELECT *

Snowflake reserves the right to add columns to these views. `SELECT *` means a future
release can silently change your result shape and break whatever consumes it. List the
columns you want.

Also add `account_name IN (...)` whenever the view exposes it and you don't need the
whole organization.

### A Reasonable Query

```sql
SELECT account_name,
       service_type,
       usage_date,
       SUM(credits_used) AS credits
  FROM SNOWFLAKE.ORGANIZATION_USAGE.METERING_DAILY_HISTORY
 WHERE usage_date >= DATEADD('month', -3, CURRENT_DATE())
 GROUP BY account_name, service_type, usage_date
 ORDER BY usage_date DESC, credits DESC;
```

### Queries to Avoid

```sql
-- Unbounded aggregate — scans all history across all accounts
SELECT COUNT(*)
  FROM SNOWFLAKE.ORGANIZATION_USAGE.QUERY_HISTORY;

-- LIMIT without time predicate — still scans full history
SELECT *
  FROM SNOWFLAKE.ORGANIZATION_USAGE.LOAD_HISTORY
 LIMIT 1;

-- SELECT * with no time bound
SELECT *
  FROM SNOWFLAKE.ORGANIZATION_USAGE.QUERY_ATTRIBUTION_HISTORY;
```

---

## Materialization Pattern

> **Pattern:** If a dashboard or console re-renders the same figures on every page load,
> **materialize the results into a table you own and refresh it on a schedule.** Point
> the UI at your table, not at `ORGANIZATION_USAGE`.

Two reasons:

1. **Latency ranges from 2 to 24 hours** depending on the view, so querying live buys no
   additional freshness.
2. **On the premium-view path**, every live hit is billable record processing — a
   scheduled refresh turns an unbounded number of reads into one predictable job.

### Latency by View Tier

| Freshness | Views |
|-----------|-------|
| ~2 hours | `METERING_DAILY_HISTORY`, `STORAGE_DAILY_HISTORY`, `DATA_TRANSFER_DAILY_HISTORY` |
| ~3 hours | `QUERY_HISTORY`, `ACCESS_HISTORY`, `LOGIN_HISTORY`, `TASK_HISTORY`, most object views |
| ~24 hours | `ACCOUNTS`, `WAREHOUSE_METERING_HISTORY`, `CONTRACT_ITEMS`, Cortex usage views |
| ~72 hours | `USAGE_IN_CURRENCY_DAILY`, `REMAINING_BALANCE_DAILY` |

Most historical views retain one year of data.

---

## Two Boundaries Worth Knowing

### Organization Scope Is a Hard Edge

`ORGANIZATION_USAGE` covers accounts within **your** organization. Accounts belonging to
a different organization — a partner, a customer on their own Snowflake contract, an
acquired entity not yet consolidated — will not appear, no matter what data-sharing
relationships exist between you.

If you need visibility into activity in an account outside your organization, that's a
data-sharing conversation with that account's owner. They would share the relevant slice
of their own `ACCOUNT_USAGE` data outbound to you.

> Map which accounts fall inside and outside the boundary before designing any report.
> The gap is invisible until someone notices a number is low.

### Billing Views and Resellers

The billing views — `USAGE_IN_CURRENCY_DAILY`, `RATE_SHEET_DAILY`,
`REMAINING_BALANCE_DAILY`, `CONTRACT_ITEMS` — are **unavailable** to organizations that
contracted through a Snowflake reseller rather than directly with Snowflake.

Two further notes:
- Figures are not final — some adjustments post at month end
- If you resell or rebill Snowflake capacity, the cost figures customers should see come
  from your own rate model, not from these views

---

## A Sensible Starting Point

1. **Confirm which path you're on.** Do you have an organization account, or a regular
   account with `ORGADMIN` enabled? This determines whether premium views are available.
2. **Write down the questions you need answered.** Credits by account is a different
   project from per-query attribution or access auditing, and they sit on different sides
   of the premium-view line.
3. **Grant the narrowest role that covers those questions** — not `ORG_USAGE_ADMIN` by
   reflex.
4. **Build one scheduled job** that lands the figures in a table you own, correctly
   time-bounded, explicit columns.
5. **Point everything downstream at your table.**

---

## Related Guides

- [ORGANIZATION_USAGE — view inventory, latency, and role mapping](https://docs.snowflake.com/en/sql-reference/organization-usage)
- [Premium views in the organization account](https://docs.snowflake.com/en/user-guide/organization-accounts-premium-views)
- [Organization accounts](https://docs.snowflake.com/en/user-guide/organization-accounts)
- [Performance (Organization Usage)](https://docs.snowflake.com/en/sql-reference/organization-usage#performance)
- [SNOWFLAKE database roles](https://docs.snowflake.com/en/sql-reference/snowflake-db-roles)

## External References

- [Snowflake Service Consumption Table](https://www.snowflake.com/legal-files/CreditConsumptionTable.pdf) (premium view rates)
