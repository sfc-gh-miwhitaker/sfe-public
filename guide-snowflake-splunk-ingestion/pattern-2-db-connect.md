# Pattern 2: Splunk DB Connect (JDBC Pull)

The most widely deployed Snowflake→Splunk integration. Splunk's DB Connect add-on connects to Snowflake via JDBC, runs SQL queries on a schedule, and ingests the results as Splunk events. Incremental ingest uses the **Rising Column** pattern to avoid re-ingesting everything on each run.

This works on Splunk Cloud and Splunk Enterprise. It is the recommended path for indexing Snowflake audit data for correlation rules, alerts, and dashboards.

---

## Architecture

```
Snowflake ACCOUNT_USAGE views
        │
        │  JDBC (Snowflake driver)
        ▼
Splunk DB Connect (scheduled inputs)
        │  incremental via Rising Column checkpoint
        ▼
Splunk index (events searchable in SPL)
```

---

## Prerequisites

- Splunk Enterprise or Splunk Cloud with DB Connect app installed
- Java installed on Splunk server (DB Connect requires JRE)
- Snowflake JDBC driver (`.jar`) placed in DB Connect driver directory
- Network connectivity: Splunk → Snowflake (port 443)

---

## Step 1: Snowflake Setup

Create a dedicated service account with least-privilege access to the audit views.

```sql
-- Run as SECURITYADMIN / SYSADMIN
USE ROLE SECURITYADMIN;

CREATE OR REPLACE ROLE SPLUNK_DBCONNECT_ROLE
  COMMENT = 'DB Connect read-only role for Splunk (Expires: 2026-10-30)';

-- Grant access to all ACCOUNT_USAGE views (no extra Snowflake cost)
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE SPLUNK_DBCONNECT_ROLE;

CREATE OR REPLACE USER SPLUNK_DBX_USER
  DEFAULT_WAREHOUSE = SPLUNK_DBX_WH
  DEFAULT_ROLE      = SPLUNK_DBCONNECT_ROLE
  TYPE              = 'service'
  COMMENT           = 'Splunk DB Connect service account (Expires: 2026-10-30)';

GRANT ROLE SPLUNK_DBCONNECT_ROLE TO USER SPLUNK_DBX_USER;

-- Dedicated warehouse (small; auto-suspends between poll intervals)
USE ROLE SYSADMIN;
CREATE OR REPLACE WAREHOUSE SPLUNK_DBX_WH
  WAREHOUSE_SIZE  = 'XSMALL'
  AUTO_SUSPEND    = 60
  AUTO_RESUME     = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Splunk DB Connect compute (Expires: 2026-10-30)';

GRANT USAGE, OPERATE ON WAREHOUSE SPLUNK_DBX_WH TO ROLE SPLUNK_DBCONNECT_ROLE;
```

### Generate a PAT (Programmatic Access Token)

DB Connect does not support key-pair authentication. Use a PAT as the password.

```sql
USE ROLE SECURITYADMIN;

-- Network policy: allow Splunk server IP(s)
-- Replace with your actual Splunk server IP or range
CREATE OR REPLACE NETWORK POLICY SPLUNK_DBX_NP
    ALLOWED_IP_LIST = ('10.0.0.0/8')   -- replace with your Splunk server CIDR
    COMMENT = 'Splunk DB Connect network policy (Expires: 2026-10-30)';

ALTER USER SPLUNK_DBX_USER SET NETWORK_POLICY = SPLUNK_DBX_NP;

-- Generate PAT — the displayed secret value is your Splunk "password"
-- Store it in a secrets manager; it cannot be retrieved after creation
ALTER USER SPLUNK_DBX_USER ADD PROGRAMMATIC ACCESS TOKEN SPLUNK_DBX_PAT;
```

---

## Step 2: Install DB Connect + JDBC Driver

**Install DB Connect:**
1. Download from [Splunkbase](https://splunkbase.splunk.com/app/2686/)
2. In Splunk: **Apps → Manage Apps → Install app from file**
3. Restart Splunk after install

**Install Snowflake JDBC driver:**
1. Download the latest `snowflake-jdbc-<version>.jar` from [Maven](https://repo1.maven.org/maven2/net/snowflake/snowflake-jdbc/)
2. Place it in: `$SPLUNK_HOME/etc/apps/splunk_app_db_connect/drivers/`

Alternatively, install the [Splunk DBX Add-on for Snowflake JDBC](https://splunkbase.splunk.com/app/6153) which packages the driver.

---

## Step 3: Configure the Connection

### Add Snowflake connection type (if not already present)

In `$SPLUNK_HOME/etc/apps/splunk_app_db_connect/default/db_connection_types.conf`, add:

```ini
[Snowflake]
serviceClass = com.splunk.dbx2.DefaultDBX2JDBC
supportedVersions = 3.0
jdbcUrlFormat = jdbc:snowflake://<host>.snowflakecomputing.com/?user=SPLUNK_DBX_USER&db=SNOWFLAKE&role=SPLUNK_DBCONNECT_ROLE&warehouse=SPLUNK_DBX_WH
jdbcDriverClass = net.snowflake.client.jdbc.SnowflakeDriver
testQuery = SELECT current_date();
displayName = Snowflake
useConnectionPool = true
```

### Create the connection in Splunk UI

1. In DB Connect: **Configuration → Identities → New Identity**
   - Username: `SPLUNK_DBX_USER`
   - Password: (paste PAT from Step 1)
2. **Configuration → Connections → New Connection**
   - Identity: (select above)
   - Connection Type: `Snowflake`
   - Edit JDBC URL:
     ```
     jdbc:snowflake://<account>.<region>.snowflakecomputing.com/?user=SPLUNK_DBX_USER&db=SNOWFLAKE&role=SPLUNK_DBCONNECT_ROLE&warehouse=SPLUNK_DBX_WH&application=SPLUNK
     ```
   - Replace `<account>` with your Snowflake account name and `<region>` with your region (omit for AWS US West)

---

## Step 4: Create Rising Column Inputs

For each table, create a DB Connect Input using **Rising Column** mode. This ensures only new rows are fetched on each run.

### LOGIN_HISTORY — Rising Column: `EVENT_ID`

`EVENT_ID` is a monotonically increasing integer — the cleanest rising column in Snowflake.

```sql
SELECT
    EVENT_ID,
    EVENT_TIMESTAMP,
    USER_NAME,
    CLIENT_IP,
    REPORTED_CLIENT_TYPE,
    IS_SUCCESS,
    ERROR_CODE,
    ERROR_MESSAGE,
    FIRST_AUTHENTICATION_FACTOR,
    SECOND_AUTHENTICATION_FACTOR,
    CLIENT_VERSION
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_ID > ?
ORDER BY EVENT_ID ASC
```

In DB Connect Input settings:
- Rising Column: `EVENT_ID`
- Checkpoint Value: `0` (start from beginning) or a recent `EVENT_ID`
- Schedule: `*/15 * * * *` (every 15 minutes)

---

### QUERY_HISTORY — Rising Column: `START_TIME`

`QUERY_HISTORY` has no integer rising column. Use `START_TIME` cast to `TIMESTAMP_NTZ` to avoid timezone checkpoint issues.

```sql
SELECT
    QUERY_ID,
    QUERY_TEXT,
    DATABASE_NAME,
    SCHEMA_NAME,
    QUERY_TYPE,
    USER_NAME,
    ROLE_NAME,
    WAREHOUSE_NAME,
    EXECUTION_STATUS,
    ERROR_MESSAGE,
    START_TIME::TIMESTAMP_NTZ       AS START_TIME_NTZ,
    END_TIME::TIMESTAMP_NTZ         AS END_TIME_NTZ,
    TOTAL_ELAPSED_TIME,
    BYTES_SCANNED,
    ROWS_PRODUCED,
    PARTITIONS_SCANNED,
    PARTITIONS_TOTAL
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME::TIMESTAMP_NTZ > ?
ORDER BY START_TIME_NTZ ASC
LIMIT 10000
```

> **Important:** Add `LIMIT 10000` (or your batch size). `QUERY_HISTORY` can have millions of rows. The `LIMIT` prevents a single poll from overwhelming both Snowflake and Splunk. Tune based on your query rate.

In DB Connect Input settings:
- Rising Column: `START_TIME_NTZ`
- Schedule: `*/30 * * * *` (every 30 minutes; ACCOUNT_USAGE lag is ~45 min)

---

### ACCESS_HISTORY — Rising Column: `QUERY_START_TIME`

```sql
SELECT
    QUERY_ID,
    QUERY_START_TIME::TIMESTAMP_NTZ     AS QUERY_START_TIME_NTZ,
    USER_NAME,
    DIRECT_OBJECTS_ACCESSED,
    BASE_OBJECTS_ACCESSED,
    OBJECTS_MODIFIED,
    OBJECT_MODIFIED_BY_DDL
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE QUERY_START_TIME::TIMESTAMP_NTZ > ?
ORDER BY QUERY_START_TIME_NTZ ASC
LIMIT 5000
```

> **Cost warning:** `ACCESS_HISTORY` is the highest-volume view. One row per query, with JSON arrays for objects accessed. Evaluate your Splunk ingest budget before enabling. Consider filtering to specific `USER_NAME` or `DATABASE_NAME` values if you only need subset coverage.

---

### SESSIONS — Rising Column: `SESSION_ID`

```sql
SELECT
    SESSION_ID,
    CREATED_ON,
    USER_NAME,
    AUTHENTICATION_METHOD,
    CLIENT_APPLICATION_ID,
    CLIENT_APPLICATION_VERSION,
    CLIENT_NET_ADDRESS
FROM SNOWFLAKE.ACCOUNT_USAGE.SESSIONS
WHERE SESSION_ID > ?
ORDER BY SESSION_ID ASC
```

---

## Rising Column Gotchas

| Issue | Cause | Fix |
|---|---|---|
| Checkpoint not advancing for `QUERY_HISTORY` | `START_TIME` is `TIMESTAMP_LTZ`; DB Connect checkpoint comparison fails across timezone formats | Cast to `TIMESTAMP_NTZ` in the query; use the alias as the rising column |
| `ACCESS_HISTORY.QUERY_START_TIME` checkpoint stuck | Same timezone issue | Same fix: cast + alias |
| Re-ingesting rows already seen | Checkpoint value lost or reset | Check DB Connect checkpoint storage; do not change the rising column name |
| Empty results despite rows existing | ACCOUNT_USAGE lag — rows not yet available | Normal behavior; do not poll faster than 15 minutes |

---

## Cost Profile

| Component | Cost Driver |
|---|---|
| Snowflake warehouse | SPLUNK_DBX_WH: XSMALL at $0.02/credit (Standard). Spins up per poll, auto-suspends. Estimate ~2 credits/day for 30-min polling intervals. |
| Splunk ingest | Per-GB pricing varies by license. `QUERY_HISTORY` at a busy org: 1–5 GB/day. `ACCESS_HISTORY`: can be 5–20 GB/day. `LOGIN_HISTORY`: small (<100 MB/day). |

**Recommendation:** Start with `LOGIN_HISTORY` only. Add `QUERY_HISTORY` with a tight `LIMIT` and `WHERE` filter. Add `ACCESS_HISTORY` only if explicitly needed for compliance.

---

[Back to README](README.md) | [Previous: Federated Search](pattern-1-federated-search.md) | [Next: External Stage](pattern-3-external-stage.md)
