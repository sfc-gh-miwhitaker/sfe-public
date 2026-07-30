# Pattern 1: Splunk Federated Search for Snowflake

**GA as of July 2026 — Splunk Cloud AWS commercial customers only.**

Splunk Federated Search lets you write SPL queries that reach into Snowflake without copying data into Splunk. Snowflake executes the heavy lifting; Splunk receives only the results. No ingestion cost, no storage growth in your SIEM index.

> **Critical constraint.** As of July 2026, this is available only for Splunk Cloud on AWS (commercial accounts). Splunk Enterprise on-prem and non-AWS Splunk Cloud deployments are not yet supported. Verify your Splunk edition before recommending this path.

---

## What Federated Search Is (and Isn't)

| | Federated Search | DB Connect (Pattern 2) |
|---|---|---|
| **Data lands in Splunk index?** | No — queried in-place | Yes — ingested as events |
| **Splunk ingest/storage cost?** | None for Snowflake data | Charged on volume |
| **Can use in SPL correlation searches?** | Only if joined/pulled into a search | Yes — data is indexed |
| **Available on Splunk Enterprise?** | Not yet | Yes |
| **Available on Splunk Cloud Azure/GCP?** | Not yet | Yes |
| **Uses Snowflake compute?** | Yes — partial query executed by Snowflake | Yes (warehouse runs during pull) |

**When to choose federated search:** Your security team runs ad-hoc investigations directly in Splunk, joins Snowflake audit data with Splunk events, and does not need Snowflake data pre-indexed. Splunk Cloud AWS is your deployment.

**When federated search is not enough:** You need Snowflake logs available as indexed Splunk events for real-time correlation rules, scheduled alerts, or dashboards that can't tolerate query-time latency against Snowflake. Use Pattern 2 (DB Connect) instead, or both.

---

## Prerequisites

- Splunk Cloud on AWS (commercial)
- Snowflake account with ACCOUNT_USAGE access
- A Snowflake service user/role scoped to the views you want to expose to Splunk
- Network connectivity between Splunk Cloud and your Snowflake account (allowlist Splunk egress IPs if you have an account-level network policy)

---

## Setup

### Step 1: Create the Snowflake service account

```sql
USE ROLE SECURITYADMIN;

-- Dedicated role for Splunk federated queries
CREATE OR REPLACE ROLE SPLUNK_FEDERATED_ROLE
  COMMENT = 'Read-only role for Splunk Federated Search (Expires: 2026-10-30)';

-- Grant access to the audit log views
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE SPLUNK_FEDERATED_ROLE;

-- Create service user
CREATE OR REPLACE USER SPLUNK_FEDERATED_USER
  DEFAULT_ROLE = SPLUNK_FEDERATED_ROLE
  TYPE = 'service'
  COMMENT = 'Splunk Federated Search service account (Expires: 2026-10-30)';

GRANT ROLE SPLUNK_FEDERATED_ROLE TO USER SPLUNK_FEDERATED_USER;

-- Warehouse for query execution
USE ROLE SYSADMIN;
CREATE OR REPLACE WAREHOUSE SPLUNK_FEDERATED_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Splunk Federated Search compute (Expires: 2026-10-30)';

GRANT USAGE, OPERATE ON WAREHOUSE SPLUNK_FEDERATED_WH TO ROLE SPLUNK_FEDERATED_ROLE;
```

### Step 2: Generate a PAT for the service user

Splunk's Snowflake connector uses username + password auth. Use a Programmatic Access Token (PAT) as the password:

```sql
USE ROLE SECURITYADMIN;

-- If your account has a network policy, create one that allows Splunk Cloud IPs
-- (check Splunk documentation for current egress IP ranges)
CREATE OR REPLACE NETWORK POLICY SPLUNK_FEDERATED_NP
    ALLOWED_IP_LIST = ('0.0.0.0/0')  -- tighten to Splunk Cloud egress IPs in prod
    COMMENT = 'Network policy for Splunk Federated Search (Expires: 2026-10-30)';

ALTER USER SPLUNK_FEDERATED_USER SET NETWORK_POLICY = SPLUNK_FEDERATED_NP;

-- Generate PAT — copy the secret value shown; this is your Splunk "password"
ALTER USER SPLUNK_FEDERATED_USER ADD PROGRAMMATIC ACCESS TOKEN SPLUNK_FEDERATED_PAT;
```

### Step 3: Add Snowflake as a federated data source in Splunk

In the Splunk Cloud UI:
1. Go to **Settings → Federated Search → Add Provider**
2. Select **Snowflake** as the provider type
3. Enter your Snowflake account identifier (e.g., `abc12345.us-east-1`)
4. Enter the service user credentials (username + PAT from Step 2)
5. Select the warehouse (`SPLUNK_FEDERATED_WH`)
6. Test the connection — Splunk will verify it can reach Snowflake

---

## Example SPL Queries

### Failed login attempts (last 24 hours)
```
| federatedsearch provider=snowflake
    query="SELECT EVENT_TIMESTAMP, USER_NAME, CLIENT_IP, ERROR_CODE, ERROR_MESSAGE
           FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
           WHERE IS_SUCCESS = 'NO'
             AND EVENT_TIMESTAMP >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
           ORDER BY EVENT_TIMESTAMP DESC"
| eval _time=strptime(EVENT_TIMESTAMP, "%Y-%m-%dT%H:%M:%S")
| table _time, USER_NAME, CLIENT_IP, ERROR_CODE, ERROR_MESSAGE
```

### Join Splunk events with Snowflake query audit
```
index=main sourcetype=app_errors
| rex field=_raw "user_id=(?<sf_user>[A-Z_]+)"
| federatedsearch provider=snowflake join type=left sf_user [
    query="SELECT USER_NAME, WAREHOUSE_NAME, TOTAL_ELAPSED_TIME, QUERY_TEXT
           FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
           WHERE START_TIME >= DATEADD('hour', -1, CURRENT_TIMESTAMP())"
]
| table _time, sf_user, WAREHOUSE_NAME, TOTAL_ELAPSED_TIME
```

### Privilege escalation detection
```
| federatedsearch provider=snowflake
    query="SELECT GRANTEE_NAME, ROLE, PRIVILEGE, GRANTED_ON, GRANTED_BY,
                  CREATED_ON
           FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
           WHERE CREATED_ON >= DATEADD('day', -1, CURRENT_TIMESTAMP())
             AND PRIVILEGE IN ('OWNERSHIP', 'CREATE USER', 'CREATE ROLE',
                               'MANAGE GRANTS', 'IMPORTED PRIVILEGES')
           ORDER BY CREATED_ON DESC"
| eval _time=strptime(CREATED_ON, "%Y-%m-%dT%H:%M:%S")
| table _time, GRANTEE_NAME, ROLE, PRIVILEGE, GRANTED_ON, GRANTED_BY
```

---

## ACCOUNT_USAGE Latency

Federated Search queries ACCOUNT_USAGE directly. That schema has a latency of **45 minutes to 3 hours** depending on the view. This is a Snowflake platform characteristic, not a Splunk limitation.

| View | Typical Lag |
|---|---|
| `QUERY_HISTORY` | ~45 minutes |
| `LOGIN_HISTORY` | ~2 hours |
| `ACCESS_HISTORY` | ~3 hours |

If you need sub-minute visibility, query `SNOWFLAKE.INFORMATION_SCHEMA` views instead — they have 7-day retention and near-real-time data, but no historical depth.

---

## Cost Profile

- **Snowflake:** You pay for the warehouse executing the federated queries. XSMALL at $0.02/credit (Standard). Queries are ad-hoc; warehouse auto-suspends.
- **Splunk:** No ingest or storage cost for federated data. You pay for the search compute.

---

## What to Watch For

- Splunk Cloud AWS only — verify before recommending to Enterprise or Azure/GCP customers.
- SPL syntax for federated queries may differ slightly from standard SPL — validate with Splunk's current documentation.
- Network policies on the Snowflake account side must allow Splunk Cloud egress IPs. Get the current IP list from Splunk support or docs — they change as Splunk scales its infrastructure.
- The `SPLUNK_FEDERATED_ROLE` needs `IMPORTED PRIVILEGES` on the `SNOWFLAKE` database. Do not grant broader privileges.

---

[Back to README](README.md) | [Next: DB Connect (Pattern 2)](pattern-2-db-connect.md)
