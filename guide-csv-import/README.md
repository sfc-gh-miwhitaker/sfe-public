# Load CSV Files into Snowflake

> [!CAUTION]
> **No support provided.** This content is for reference only. Review and validate before applying to any production workflow.

![Expires](https://img.shields.io/badge/Expires-2027--03--06-orange)

**Pair-programmed by:** SE Community + Cortex Code
**Created:** 2026-03-06 | **Expires:** 2027-03-06 | **Status:** ACTIVE

A step-by-step guide to loading CSV files into Snowflake using Snowsight. Covers one-time setup, a repeatable import process, and optional automation.

**Time:** ~15 minutes for first import | **Result:** CSV data queryable in Snowflake

## Who This Is For

Anyone who needs to load CSV files into Snowflake on a regular basis -- weekly exports from a POS system, monthly reports from a vendor, ad-hoc data drops from a partner. You need a Snowflake account with permissions to create databases, schemas, and stages. No prior Snowflake experience required.

**Already comfortable with Snowflake?** Skip to [Part 2](#part-2-upload-and-load-repeatable) for the COPY INTO pattern, or [Part 3](#part-3-automation-optional) if you want to move from manual uploads to Snowpipe or scheduled tasks.

---

## Prerequisites

Before you begin, ensure you have:

- Snowflake account credentials (username, password, account URL)
- One or more CSV files ready to load
- Knowledge of the columns in your CSV files (open one in a text editor or spreadsheet to check)

---

## Part 1: One-Time Setup

Complete these steps once to prepare your environment. All SQL runs in a Snowsight worksheet: **Projects > Worksheets > + Worksheet**.

### 1. Create Database and Schema

Choose names that make sense for your use case. This guide uses a retail transactions example -- replace `MY_DATABASE` and `MY_SCHEMA` with your own names.

```sql
CREATE DATABASE MY_DATABASE;
CREATE SCHEMA MY_DATABASE.MY_SCHEMA;
USE SCHEMA MY_DATABASE.MY_SCHEMA;
```

### 2. Create a Named File Format

A named file format saves you from repeating format options on every COPY INTO. Create it once, reference it everywhere.

```sql
CREATE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    COMMENT = 'Standard CSV with header row and optional double-quote enclosure';
```

> [!TIP]
> If your CSV uses a different delimiter (pipe, tab, semicolon), add `FIELD_DELIMITER = '|'` (or `'\t'`, `';'`). See [File Format Options](https://docs.snowflake.com/en/sql-reference/sql/create-file-format#type-csv) for the full list.

### 3. Create an Upload Stage

A stage is a landing zone where CSV files are uploaded before loading into tables.

```sql
CREATE STAGE CSV_UPLOADS
    DIRECTORY = (ENABLE = TRUE);
```

### 4. Create Your Table

Define columns to match your CSV structure. The example below models retail sales transactions -- **replace these columns with your own**.

```sql
CREATE TABLE SALES_TRANSACTIONS (
    transaction_id      VARCHAR,
    transaction_date    VARCHAR,
    transaction_time    VARCHAR,
    store_location      VARCHAR,
    register_id         VARCHAR,
    item_name           VARCHAR,
    item_category       VARCHAR,
    quantity            VARCHAR,
    unit_price          VARCHAR,
    total_amount        VARCHAR,
    payment_method      VARCHAR,
    employee_id         VARCHAR
);
```

> [!IMPORTANT]
> **Why VARCHAR for everything?** Loading all columns as VARCHAR avoids type-conversion errors during import. Once the data is in Snowflake, you can cast columns in views or queries (e.g., `quantity::NUMBER`, `transaction_date::DATE`). This is the safest approach when you're getting started.

### Customize for Your Data

Not sure what columns your CSV has? Upload a file first (see [Part 2, Step 1](#1-upload-csv-files)), then inspect it:

```sql
SELECT $1, $2, $3, $4, $5 FROM @CSV_UPLOADS LIMIT 5;
```

Each `$N` corresponds to a column position. Count the columns, name them, and create your table accordingly.

You can also let Snowflake detect the schema automatically:

```sql
SELECT *
FROM TABLE(INFER_SCHEMA(
    LOCATION => '@CSV_UPLOADS',
    FILE_FORMAT => 'CSV_FORMAT'
));
```

This returns the detected column names and types from the CSV header row, which you can use to build your CREATE TABLE statement.

---

## Part 2: Upload and Load (Repeatable)

Repeat these steps each time you have new CSV files to import.

### 1. Upload CSV Files

In Snowsight, navigate to: **Data > Databases > MY_DATABASE > MY_SCHEMA > Stages > CSV_UPLOADS**

Click **+ Files**, then drag and drop your CSV files or browse to select them.

> [!TIP]
> **Prefer a wizard?** Snowsight also offers a guided load experience: **Data > Databases > [your database] > [your schema] > [your table] > Load Data**. This combines upload and COPY INTO in a single UI flow. The manual approach below gives you more control and is easier to repeat.

### 2. Load Data with COPY INTO

In a SQL Worksheet, run:

```sql
USE SCHEMA MY_DATABASE.MY_SCHEMA;

COPY INTO SALES_TRANSACTIONS
FROM @CSV_UPLOADS
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';
```

`ON_ERROR = 'CONTINUE'` loads valid rows and skips any rows with errors. After loading, the output shows how many rows were loaded and how many had errors per file.

> [!TIP]
> If you see errors in the COPY output, inspect them with:
> ```sql
> SELECT *
> FROM TABLE(VALIDATE(SALES_TRANSACTIONS, LAST_QUERY_ID()));
> ```
> This returns the specific rows and error messages from the most recent COPY INTO.

### 3. Verify the Load

```sql
-- Check total row count
SELECT COUNT(*) FROM SALES_TRANSACTIONS;

-- Preview the data
SELECT * FROM SALES_TRANSACTIONS LIMIT 20;
```

### 4. Clean Up the Stage

Remove processed files to avoid reloading them on the next COPY INTO:

```sql
REMOVE @CSV_UPLOADS;
```

> [!NOTE]
> COPY INTO tracks which files have been loaded (by name and checksum) and skips duplicates by default. Cleaning the stage is still good practice to keep things tidy and avoid confusion, but accidentally re-running COPY INTO without cleaning won't create duplicate rows.

---

## Part 3: Automation (Optional)

Once comfortable with manual imports, consider these options to eliminate repetitive work.

| Method | How It Works | Best For |
|---|---|---|
| [Snowpipe](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-intro) | Auto-loads files dropped in cloud storage (S3, Azure Blob, GCS) | Hands-off, near-real-time ingestion |
| [Scheduled Task](https://docs.snowflake.com/en/sql-reference/sql/create-task) | Runs a COPY INTO on a cron schedule (e.g., every Monday at 6 AM) | Regular batch loads on a predictable cadence |

**Snowpipe example** -- automatically load any CSV that lands in your stage:

```sql
CREATE PIPE MY_SCHEMA.SALES_PIPE
    AUTO_INGEST = TRUE
AS
    COPY INTO SALES_TRANSACTIONS
    FROM @CSV_UPLOADS
    FILE_FORMAT = CSV_FORMAT;
```

**Scheduled task example** -- run COPY INTO every Monday at 6 AM UTC:

```sql
CREATE TASK MY_SCHEMA.WEEKLY_LOAD_TASK
    WAREHOUSE = MY_WAREHOUSE
    SCHEDULE = 'USING CRON 0 6 * * 1 UTC'
AS
    COPY INTO SALES_TRANSACTIONS
    FROM @CSV_UPLOADS
    FILE_FORMAT = CSV_FORMAT;

ALTER TASK MY_SCHEMA.WEEKLY_LOAD_TASK RESUME;
```

---

## Quick Reference

| Action | Command |
|---|---|
| Set context | `USE SCHEMA MY_DATABASE.MY_SCHEMA;` |
| List staged files | `LIST @CSV_UPLOADS;` |
| Preview raw CSV | `SELECT $1, $2, $3 FROM @CSV_UPLOADS LIMIT 10;` |
| Load data | `COPY INTO SALES_TRANSACTIONS FROM @CSV_UPLOADS FILE_FORMAT = CSV_FORMAT;` |
| Row count | `SELECT COUNT(*) FROM SALES_TRANSACTIONS;` |
| Inspect errors | `SELECT * FROM TABLE(VALIDATE(SALES_TRANSACTIONS, LAST_QUERY_ID()));` |
| Clear stage | `REMOVE @CSV_UPLOADS;` |

---

## Troubleshooting

| Error | Solution |
|---|---|
| **Column count mismatch** | Preview your CSV with `SELECT $1, $2, ... FROM @CSV_UPLOADS LIMIT 5` to check the column count. Adjust your table definition or add/remove columns. |
| **Date/number format error** | Load as VARCHAR first (as shown above), then cast in queries: `transaction_date::DATE`. This avoids load-time failures. |
| **Permission denied** | You need CREATE privileges on the database/schema. Contact your Snowflake administrator for role or grant updates. |
| **Object does not exist** | Verify you ran `USE SCHEMA MY_DATABASE.MY_SCHEMA;` first. Snowflake requires context to resolve unqualified object names. |
| **Duplicate data after re-run** | COPY INTO skips previously loaded files by default. If you recreated a file with the same name but different content, use `FORCE = TRUE` or rename the file. |

---

## References

| Resource | URL |
|---|---|
| COPY INTO (table) | https://docs.snowflake.com/en/sql-reference/sql/copy-into-table |
| CREATE STAGE | https://docs.snowflake.com/en/sql-reference/sql/create-stage |
| CREATE FILE FORMAT | https://docs.snowflake.com/en/sql-reference/sql/create-file-format |
| Staging files using Snowsight | https://docs.snowflake.com/en/user-guide/data-load-local-file-system-stage-ui |
| INFER_SCHEMA | https://docs.snowflake.com/en/sql-reference/functions/infer_schema |
| Snowpipe overview | https://docs.snowflake.com/en/user-guide/data-load-snowpipe-intro |
| CREATE TASK | https://docs.snowflake.com/en/sql-reference/sql/create-task |
| VALIDATE function | https://docs.snowflake.com/en/sql-reference/functions/validate |
