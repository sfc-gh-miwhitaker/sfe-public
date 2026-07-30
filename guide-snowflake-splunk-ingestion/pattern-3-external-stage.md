# Pattern 3: External Stage Export → Splunk

Export Snowflake audit data to cloud storage (S3, Azure Blob, or GCS) on a schedule, then have Splunk ingest from that storage. This decouples Snowflake from Splunk — no direct database connection required — and handles high-cardinality tables more gracefully than DB Connect's JDBC pull.

**Best for:**
- High-volume tables (`QUERY_HISTORY`, `ACCESS_HISTORY`) where DB Connect's JDBC pull is slow or expensive
- Organizations that already use Splunk's cloud storage add-ons and want a consistent ingestion pattern
- Cases where Splunk cannot establish direct JDBC connectivity to Snowflake (firewall constraints)

---

## Architecture

```
Snowflake ACCOUNT_USAGE views
        │
        │  Snowflake Task (scheduled)
        │  COPY INTO external stage (S3/Azure/GCS)
        ▼
Cloud Storage (S3 / Azure Blob / GCS)
        │
        │  Splunk S3/Azure/GCS Add-on
        ▼
Splunk index (events)
```

---

## Prerequisites

- A Snowflake external stage pointing to your cloud storage bucket
- An external stage already set up (storage integration + stage object)
- [Splunk Add-on for Amazon S3](https://splunkbase.splunk.com/app/1876/) (or equivalent for Azure/GCS) installed in Splunk
- IAM role / service principal with write access to the bucket (Snowflake side) and read access (Splunk side)

---

## Step 1: Create the External Stage

If you do not have an external stage set up, here is the pattern for S3. Azure and GCS follow the same structure with cloud-specific syntax.

```sql
USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- Storage integration (account-level object; admin creates once)
-- If SFE_S3_STORAGE_INTEGRATION already exists for your org, skip this
CREATE STORAGE INTEGRATION IF NOT EXISTS SFE_S3_STORAGE_INTEGRATION
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<account-id>:role/<role-name>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<your-bucket>/snowflake-audit-export/')
  COMMENT = 'S3 integration for Splunk audit log export (Expires: 2026-10-30)';

-- After creating, retrieve the IAM values to configure the trust relationship
DESC INTEGRATION SFE_S3_STORAGE_INTEGRATION;
-- Copy STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID
-- Add these to the IAM role trust policy in AWS

-- External stage pointing to the export bucket prefix
CREATE STAGE IF NOT EXISTS SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.AUDIT_STAGE
  STORAGE_INTEGRATION = SFE_S3_STORAGE_INTEGRATION
  URL = 's3://<your-bucket>/snowflake-audit-export/'
  FILE_FORMAT = (TYPE = 'JSON' COMPRESSION = 'AUTO')
  COMMENT = 'Splunk audit log export stage (Expires: 2026-10-30)';
```

> For Azure and GCS, replace `STORAGE_PROVIDER` and the corresponding ARN/URL fields. Syntax is identical in structure — see [Snowflake external stage docs](https://docs.snowflake.com/en/sql-reference/sql/create-stage) for cloud-specific parameters.

---

## Step 2: Create the Export Schema and Task

```sql
USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT
  COMMENT = 'Splunk audit export tasks and views (Expires: 2026-10-30)';

CREATE OR REPLACE WAREHOUSE SPLUNK_EXPORT_WH
  WAREHOUSE_SIZE  = 'XSMALL'
  AUTO_SUSPEND    = 120
  AUTO_RESUME     = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Splunk audit export compute (Expires: 2026-10-30)';
```

---

## Step 3: Incremental Export Tasks

The key to incremental export is a time window: each task run exports a fixed lookback window (e.g., the last 2 hours) with a small overlap buffer to catch rows that arrived late due to ACCOUNT_USAGE lag. Splunk deduplicates on `_raw` or a unique field.

### LOGIN_HISTORY — every 30 minutes

```sql
CREATE OR REPLACE TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.EXPORT_LOGIN_HISTORY
  WAREHOUSE = SPLUNK_EXPORT_WH
  SCHEDULE  = 'USING CRON */30 * * * * UTC'
  COMMENT   = 'Export LOGIN_HISTORY to S3 for Splunk (Expires: 2026-10-30)'
AS
COPY INTO @SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.AUDIT_STAGE/login_history/
FROM (
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
        SECOND_AUTHENTICATION_FACTOR
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
    WHERE EVENT_TIMESTAMP >= DATEADD('hour', -3, CURRENT_TIMESTAMP())
      AND EVENT_TIMESTAMP <  DATEADD('minute', -5, CURRENT_TIMESTAMP())
)
FILE_FORMAT = (TYPE = 'JSON' COMPRESSION = 'AUTO')
OVERWRITE = FALSE;

ALTER TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.EXPORT_LOGIN_HISTORY RESUME;
```

> **Window design:** Export rows from 3 hours ago to 5 minutes ago. The 3-hour lookback covers ACCOUNT_USAGE lag (up to 3 hours for some views). The 5-minute right-side buffer avoids exporting rows that haven't fully propagated. Splunk's `OVERWRITE = FALSE` means existing files aren't replaced — configure Splunk to deduplicate on `EVENT_ID`.

### QUERY_HISTORY — every hour

```sql
CREATE OR REPLACE TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.EXPORT_QUERY_HISTORY
  WAREHOUSE = SPLUNK_EXPORT_WH
  SCHEDULE  = '60 MINUTE'
  COMMENT   = 'Export QUERY_HISTORY to S3 for Splunk (Expires: 2026-10-30)'
AS
COPY INTO @SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.AUDIT_STAGE/query_history/
FROM (
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
        START_TIME,
        END_TIME,
        TOTAL_ELAPSED_TIME,
        BYTES_SCANNED,
        ROWS_PRODUCED
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE START_TIME >= DATEADD('hour', -3, CURRENT_TIMESTAMP())
      AND START_TIME <  DATEADD('minute', -5, CURRENT_TIMESTAMP())
)
FILE_FORMAT = (TYPE = 'JSON' COMPRESSION = 'AUTO')
OVERWRITE = FALSE;

ALTER TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.EXPORT_QUERY_HISTORY RESUME;
```

### ACCESS_HISTORY — every hour (filter to sensitive databases)

`ACCESS_HISTORY` can be very large. Consider filtering to specific databases or user groups rather than exporting everything.

```sql
CREATE OR REPLACE TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.EXPORT_ACCESS_HISTORY
  WAREHOUSE = SPLUNK_EXPORT_WH
  SCHEDULE  = '60 MINUTE'
  COMMENT   = 'Export ACCESS_HISTORY to S3 for Splunk (Expires: 2026-10-30)'
AS
COPY INTO @SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.AUDIT_STAGE/access_history/
FROM (
    SELECT
        QUERY_ID,
        QUERY_START_TIME,
        USER_NAME,
        DIRECT_OBJECTS_ACCESSED,
        BASE_OBJECTS_ACCESSED,
        OBJECTS_MODIFIED
    FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
    WHERE QUERY_START_TIME >= DATEADD('hour', -3, CURRENT_TIMESTAMP())
      AND QUERY_START_TIME <  DATEADD('minute', -5, CURRENT_TIMESTAMP())
      -- Optionally scope to specific databases:
      -- AND ARRAY_SIZE(DIRECT_OBJECTS_ACCESSED) > 0
)
FILE_FORMAT = (TYPE = 'JSON' COMPRESSION = 'AUTO')
OVERWRITE = FALSE;

ALTER TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.EXPORT_ACCESS_HISTORY RESUME;
```

---

## Step 4: Configure Splunk S3 Add-on

1. Install [Splunk Add-on for Amazon S3](https://splunkbase.splunk.com/app/1876/) (or Azure/GCS equivalent)
2. Configure AWS credentials (IAM role or access key) with `s3:GetObject`, `s3:ListBucket` on the export bucket prefix
3. Add an S3 input pointing to each prefix:
   - `s3://<your-bucket>/snowflake-audit-export/login_history/` → sourcetype `snowflake:login`
   - `s3://<your-bucket>/snowflake-audit-export/query_history/` → sourcetype `snowflake:query`
   - `s3://<your-bucket>/snowflake-audit-export/access_history/` → sourcetype `snowflake:access`
4. Set **Ingestion Mode** to "One-time for new files" — Splunk polls for new files and ingests them once

---

## Deduplication in Splunk

Because the export window overlaps runs (3-hour lookback on every poll), the same row may appear in multiple export files. In Splunk:

```
sourcetype="snowflake:login"
| dedup EVENT_ID
```

Or set `EVENT_ID` (or `QUERY_ID`) as the Splunk `_raw` key for the sourcetype so Splunk handles deduplication at index time.

---

## Teardown

```sql
ALTER TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.EXPORT_LOGIN_HISTORY SUSPEND;
ALTER TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.EXPORT_QUERY_HISTORY SUSPEND;
ALTER TASK SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT.EXPORT_ACCESS_HISTORY SUSPEND;

DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SPLUNK_EXPORT CASCADE;
DROP WAREHOUSE IF EXISTS SPLUNK_EXPORT_WH;
-- Note: keep SFE_S3_STORAGE_INTEGRATION if shared with other projects
```

---

## Cost Profile

| Component | Notes |
|---|---|
| Snowflake warehouse | XSMALL tasks, hourly schedule. Typically < 1 credit/day per task. |
| Snowflake data egress | COPY INTO charges standard egress fees for data leaving to S3/Azure/GCS. For audit logs, typically small (< $5/month). |
| Cloud storage | S3/Azure/GCS storage at standard rates. Audit logs compress well (JSON gzip). Lifecycle-delete old export files after Splunk confirms ingestion. |
| Splunk ingest | Per-GB; same as DB Connect. Scoping your `WHERE` clause is the primary cost lever. |

---

[Back to README](README.md) | [Previous: DB Connect](pattern-2-db-connect.md) | [Next: Sentry](pattern-4-sentry.md)
