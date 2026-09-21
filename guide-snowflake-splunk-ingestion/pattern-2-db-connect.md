# Pattern 2: Splunk DB Connect (JDBC Pull)

The most widely deployed Snowflake→Splunk integration. Splunk's DB Connect add-on connects to Snowflake via JDBC, runs SQL queries on a schedule, and ingests the results as Splunk events. Incremental ingest uses the **Rising Column** pattern to avoid re-ingesting everything on each run.

This works on Splunk Cloud and Splunk Enterprise. It is the recommended path for indexing Snowflake audit data for correlation rules, alerts, and dashboards.

---

## Architecture

```text
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
  COMMENT = 'DB Connect read-only role for Splunk (Expires: 2027-03-21)';

-- Grant access to all ACCOUNT_USAGE views (no extra Snowflake cost)
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE SPLUNK_DBCONNECT_ROLE;

CREATE OR REPLACE USER SPLUNK_DBX_USER
  DEFAULT_WAREHOUSE = SPLUNK_DBX_WH
  DEFAULT_ROLE      = SPLUNK_DBCONNECT_ROLE
  -- NOTE: TYPE = SERVICE means this user CANNOT use a PAT unless it is subject to
  -- a network policy. The "Generate a PAT" step below sets one -- do not remove it,
  -- or the PAT stops working. TYPE = SERVICE_AGENT carries no such requirement.
  TYPE              = 'service'
  COMMENT           = 'Splunk DB Connect service account (Expires: 2027-03-21)';

GRANT ROLE SPLUNK_DBCONNECT_ROLE TO USER SPLUNK_DBX_USER;

-- Dedicated warehouse (small; auto-suspends between poll intervals)
USE ROLE SYSADMIN;
CREATE OR REPLACE WAREHOUSE SPLUNK_DBX_WH
  WAREHOUSE_SIZE  = 'XSMALL'
  AUTO_SUSPEND    = 45          -- see "Sizing AUTO_SUSPEND for a poller" below
  AUTO_RESUME     = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Splunk DB Connect compute (Expires: 2027-03-21)';

GRANT USAGE, OPERATE ON WAREHOUSE SPLUNK_DBX_WH TO ROLE SPLUNK_DBCONNECT_ROLE;
```

### Sizing AUTO_SUSPEND for a poller

Snowflake bills warehouses per-second **with a 60-second minimum charged on every
resume**, and the minimum restarts each time the warehouse resumes. A poller resumes
once per interval, so every poll costs at least 60 seconds no matter how fast the
queries are.

That makes the billed cost of one cycle `MAX(run_duration, 60s)`, where
`run_duration = query_burst + AUTO_SUSPEND`. For a burst of roughly 10–15 seconds:

| `AUTO_SUSPEND` | Run duration | Billed | Notes |
| --- | --- | --- | --- |
| 30 | ~42 s | 60 s | Pays the minimum, discards ~18 s already paid for |
| **45** | **~57 s** | **60 s** | **Consumes the minimum without exceeding it** |
| 60 | ~72 s | 72 s | 20% more than necessary |
| 300 | ~312 s | 312 s | Warehouse effectively never suspends |

So the sweet spot is roughly `60s − your burst duration`. Setting it lower saves
nothing; setting it higher costs real credits on every poll. Measure your own burst
length before tuning:

```sql
SELECT
    COUNT(*)                                        AS polls,
    ROUND(AVG(TOTAL_ELAPSED_TIME) / 1000, 1)        AS avg_query_seconds,
    ROUND(MAX(TOTAL_ELAPSED_TIME) / 1000, 1)        AS max_query_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE WAREHOUSE_NAME = 'SPLUNK_DBX_WH'
  AND START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());
```

> **The bigger lever is interval, not `AUTO_SUSPEND`.** Because every poll pays a
> 60-second floor, halving the poll frequency halves that floor. Going from a
> 5-minute to a 30-minute interval removes roughly five-sixths of the minimum-billing
> overhead — far more than any `AUTO_SUSPEND` tuning can.

### Generate a PAT (Programmatic Access Token)

DB Connect does not support key-pair authentication. Use a PAT as the password.

```sql
USE ROLE SECURITYADMIN;

-- Network policy: allow Splunk server IP(s)
-- Replace with your actual Splunk server IP or range
CREATE OR REPLACE NETWORK POLICY SPLUNK_DBX_NP
    ALLOWED_IP_LIST = ('10.0.0.0/8')   -- replace with your Splunk server CIDR
    COMMENT = 'Splunk DB Connect network policy (Expires: 2027-03-21)';

ALTER USER SPLUNK_DBX_USER SET NETWORK_POLICY = SPLUNK_DBX_NP;

-- Generate PAT — the displayed secret value is your Splunk "password"
-- Store it in a secrets manager; it cannot be retrieved after creation
ALTER USER SPLUNK_DBX_USER ADD PROGRAMMATIC ACCESS TOKEN SPLUNK_DBX_PAT;
```

> **The network policy above is a prerequisite, not just hardening.** A `TYPE = SERVICE` user cannot use a PAT at all unless it is subject to a network policy. Because `SPLUNK_DBX_USER` is a service user, removing `SPLUNK_DBX_NP` breaks DB Connect authentication entirely — and it surfaces as a credential error, not a network-policy one. `TYPE = SERVICE_AGENT` carries no such requirement if you need a PAT without a network policy.

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

     ```text
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
WHERE START_TIME::TIMESTAMP_NTZ >= ?
ORDER BY START_TIME_NTZ ASC, QUERY_ID ASC
LIMIT 10000
```

> **Important:** Add `LIMIT 10000` (or your batch size). `QUERY_HISTORY` can have millions of rows. The `LIMIT` prevents a single poll from overwhelming both Snowflake and Splunk. Tune based on your query rate.

> **Why `>=` and not `>` here.** `START_TIME` is **not unique** — many statements share
> the same millisecond. If the `LIMIT` happens to cut through the middle of a group of
> rows sharing one timestamp `T`, the checkpoint advances to `T` and the next poll's
> `> T` predicate silently skips every remaining row at `T`. Using `>=` re-reads the
> boundary timestamp instead of skipping past it, which means you **must** deduplicate
> on `QUERY_ID` downstream. Prefer re-reading a few rows over losing them. The
> `QUERY_ID` tiebreaker in `ORDER BY` makes the page boundary deterministic.

In DB Connect Input settings:

- Rising Column: `START_TIME_NTZ`
- Schedule: `*/30 * * * *` (every 30 minutes; ACCOUNT_USAGE lag is ~45 min)
- Splunk-side dedupe: key on `QUERY_ID`

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
| --- | --- | --- |
| Checkpoint not advancing for `QUERY_HISTORY` | `START_TIME` is `TIMESTAMP_LTZ`; DB Connect checkpoint comparison fails across timezone formats | Cast to `TIMESTAMP_NTZ` in the query; use the alias as the rising column |
| `ACCESS_HISTORY.QUERY_START_TIME` checkpoint stuck | Same timezone issue | Same fix: cast + alias |
| Re-ingesting rows already seen | Checkpoint value lost or reset | Check DB Connect checkpoint storage; do not change the rising column name |
| Empty results despite rows existing | ACCOUNT_USAGE lag — rows not yet available | Normal behavior; do not poll faster than 15 minutes |
| Rows missing at `LIMIT` boundaries | Non-unique rising column (`START_TIME`) combined with `>` and a `LIMIT` — the batch cuts mid-timestamp and the checkpoint steps over the remainder | Use `>=`, add a unique `ORDER BY` tiebreaker, and dedupe downstream on `QUERY_ID` |
| Rows missing with no obvious pattern | Query uses a **bounded** window (`ts >= ? AND ts <= ?`) rather than an open-ended rising column. Once the window closes, rows that land late are never re-read | Never bound the upper end. Use `col > ?` / `col >= ?` so late arrivals are still picked up on a later poll |
| Rows missing or duplicated across pages | `LIMIT ? OFFSET ?` pagination over a non-unique `ORDER BY` — there is no guaranteed total order, so page boundaries shift between calls | Add a unique tiebreaker to `ORDER BY`, or switch to keyset pagination (`WHERE col > last_seen`) instead of `OFFSET` |
| Grant revocations never appear | `GRANTS_TO_ROLES` / `GRANTS_TO_USERS` filtered on `CREATED_ON` only see grants being **added** | Also select `DELETED_ON` and ingest the full daily snapshot — see the note in the README view table |

---

## Cost Profile

| Component | Cost Driver |
| --- | --- |
| Snowflake warehouse | `SPLUNK_DBX_WH`: XSMALL, which consumes 1 credit per hour while running. Spins up per poll, auto-suspends, billed per second after a 60-second minimum per resume. At 30-minute polling that is 48 resumes/day, so a floor of ~0.8 credits/day and roughly 1–2 credits/day in practice depending on how long each poll runs. Measure your own. Convert to currency at your contract rate. |
| Splunk ingest | Per-GB pricing varies by license. `QUERY_HISTORY` at a busy org: 1–5 GB/day. `ACCESS_HISTORY`: can be 5–20 GB/day. `LOGIN_HISTORY`: small (<100 MB/day). |

**Recommendation:** Start with `LOGIN_HISTORY` only. Add `QUERY_HISTORY` with a tight `LIMIT` and `WHERE` filter. Add `ACCESS_HISTORY` only if explicitly needed for compliance.

---

## Anti-Patterns Seen in the Field

These are the failure modes that show up in real deployments, including vendor-built
connectors you do not control. Every one of them is silent — the integration reports
healthy while dropping data.

| Anti-pattern | Why it looks fine | What it actually does |
| --- | --- | --- |
| Polling every 1–5 minutes | Feels like "near real-time" | ACCOUNT_USAGE latency is 45 min–3 hr. The cursor outruns the data, and a short bounded window orphans rows permanently. Latency is structural — you cannot poll your way past it |
| Bounded window (`ts BETWEEN ? AND ?`) | Looks tidy and idempotent | Any row that materialises after the window closes is never collected |
| `SELECT *` on `QUERY_HISTORY` | Fewer config decisions | Ships `QUERY_TEXT` (up to 100K chars) off-platform — which can contain literals, identifiers, or pasted secrets. Also breaks when Snowflake adds columns; the docs advise against it explicitly |
| `LIMIT ? OFFSET ?` over `ORDER BY <non-unique>` | Standard pagination idiom | No stable total order between pages; rows skipped or duplicated at boundaries |
| Statement timeout set just above observed max | Looks like a safety net | Leaves no headroom. An ACCOUNT_USAGE slowdown then fails the poll, and unless the connector retries, that window is lost |
| Enabling every view on day one | "Complete coverage" | Low-churn object views (`STAGES`, `GRANTS_TO_*`, `DATA_TRANSFER_HISTORY`) polled at high frequency burn credits to return nothing. Match cadence to churn |

### Verify your own ingest completeness

Do not assume the connector is keeping up. Compare what it read against what actually
happened, over a window old enough that all latency has settled:

```sql
-- Rows the connector's own queries returned vs events that actually occurred.
-- Window ends 24 hours ago so ACCOUNT_USAGE latency has settled; adjust the
-- 7-day span to match how far back you want to reconcile.
SET window_end   = DATEADD('day', -1, CURRENT_TIMESTAMP())::TIMESTAMP_NTZ;
SET window_start = DATEADD('day', -7, $window_end);

WITH delivered AS (
    SELECT COALESCE(SUM(ROWS_PRODUCED), 0) AS rows_delivered
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE WAREHOUSE_NAME = 'SPLUNK_DBX_WH'
      AND START_TIME >= $window_start
      AND START_TIME <  $window_end
      AND QUERY_TEXT ILIKE '%ACCOUNT_USAGE.LOGIN_HISTORY%'
),
actual AS (
    SELECT COUNT(*) AS events_occurred
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
    WHERE EVENT_TIMESTAMP >= $window_start
      AND EVENT_TIMESTAMP <  $window_end
)
SELECT
    a.events_occurred,
    d.rows_delivered,
    ROUND(d.rows_delivered / NULLIF(a.events_occurred, 0) * 100, 1) AS pct_captured
FROM actual a CROSS JOIN delivered d;
```

A healthy incremental feed lands at or slightly above 100% — slightly above is normal
and expected when you use `>=` with downstream dedupe. Anything meaningfully below 100%
means rows are being dropped, and the cause is almost always poll interval, a bounded
window, or `OFFSET` pagination.

---

[Back to README](README.md) | [Previous: Federated Search](pattern-1-federated-search.md) | [Next: External Stage](pattern-3-external-stage.md)
