![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--01--09-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Make Sense of What Sigma Writes Back to Snowflake

You turned on Sigma input tables, typed three rows, opened the write schema in Snowflake, and found tables named `SIGDS_2e4089ed_...` with columns like `SAKZ1N4J3M` and a dozen rows instead of three. This guide explains what you are looking at, why it is built that way, and the supported pattern for turning it into clean, typed, governed tables everyone else can use. Every behavior described here was observed on a live Sigma connection on 2026-11-10 or comes from Sigma's own documentation.

**Audience:** Snowflake administrators and data engineers who are new to Sigma, or Sigma builders who are new to Snowflake.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-11-10 | **Last verified:** 2026-11-10 | **Expires:** 2027-01-09 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## Start Here

The short answer, if that is all you need:

1. **The `SIGDS_` tables are Sigma's private storage, not your table.** Sigma documents them as "optimized for storage" and says you cannot query them directly or modify them. Leave them alone.
2. **Create a warehouse view in Sigma** for each input table you need outside Sigma. That is the readable, supported version.
3. **Wrap the warehouse view in your own view** in a separate schema, with the types, names, and filters you want. Grant everyone else access to that, never to the write schema.

To see all of this on synthetic data without a Sigma account, open Snowsight, paste [`sql/walkthrough.sql`](sql/walkthrough.sql) into a worksheet, and select **Run All**. Remove it with [`sql/teardown.sql`](sql/teardown.sql).

Prefer plain language? Read [ELI5.md](ELI5.md).

## How it fits together

```text
 Sigma workbook                      Snowflake write schema (Sigma owns it)
 ┌─────────────────┐  MERGE per edit  ┌──────────────────────────────────────┐
 │ Input table     │ ───────────────> │ SIGDS_<id>          data, versioned  │
 │ Region|Target|..│                  │ SIGDS_WAL_DS_<id>   edit log         │
 └─────────────────┘                  │ INPUT_TABLE_AUDIT_LOG_<id>  view     │
         │ "Create warehouse view"    │ <YOUR_NAME>         warehouse view   │
         └──────────────────────────> └──────────────────┬───────────────────┘
                                                         │ SELECT
                                      Your schema        ▼
                                      ┌──────────────────────────────────────┐
                                      │ Contract view: typed, renamed,       │
                                      │ filtered. Everyone else reads this.  │
                                      │ Optional snapshot table for history. │
                                      └──────────────────────────────────────┘
```

## What you are looking at

For **each** input table, Sigma creates these objects in the write schema. Object names below are from a real test run.

| Object | Kind | What it is | Query it? |
| --- | --- | --- | --- |
| `SIGDS_2e4089ed_ee9a_4ad1_a329_c61ce0f496cf` | Table | The data, stored as a version history | No |
| `SIGDS_WAL_DS_2e4089ed_ee9a_4ad1_a329_c61ce0f496cf` | Table | The edit log (Sigma calls it a write-ahead log or WAL): one row per save, with binary IDs and the edit payload as text | No |
| `INPUT_TABLE_AUDIT_LOG_2e4089ed_ee9a_4ad1_a329_c61ce0f496cf` | View | A readable audit trail of data and column changes, created automatically | Yes, for audit |
| `NEW_INPUT_TABLE` (named after the element) | View | The warehouse view, only if you create one | Yes |

Why the data table is so hard to read:

- **Column names are random codes.** In the test, `Region` was stored as `SAKZ1N4J3M`, `Target` as `JQZEOOGJ6P`, and `Notes` as `3HNOK9IT3B`. The human names live in Sigma, not in the table.
- **Every cell edit adds a row.** Three typed rows produced twelve stored rows. Each has an `ID`, a `ROW_VERSION`, `UPDATED_BY` (the editor's email), and `UPDATED_AT`. A deleted row gets a `TOMBSTONE_VERSION`. The current table is "newest version of each ID that has no tombstone."
- **Names are lowercase, so they must be double-quoted.** `SELECT ... FROM SIGDS_2e4089ed_...` fails with "does not exist". Only `"SIGDS_2e4089ed_..."` works. See [Snowflake identifier rules](https://docs.snowflake.com/en/sql-reference/identifiers-syntax).
- **Types follow the Sigma column type.** The `Target` column was left as text in Sigma, so it was stored as `TEXT` even though it held numbers.

This design is what lets many people edit at once, keeps a full history, and allows recovery. It is not meant to be read by people. Sigma can change it at any time, and the random column codes are different for every input table, so any SQL you write against it is tied to one table and one format version.

Run section 3 of the walkthrough to see the same shape, with 11 stored versions behind 4 visible rows.

## Step 1: Set up the connection the right way

Do this once, before anyone builds input tables. Sections 1 and 2 of the walkthrough create all of it.

| Decision | Recommendation | Why |
| --- | --- | --- |
| Write destination | A **dedicated schema** used only by Sigma | Sigma recommends it, and hides that schema from its own data browser once it is a write destination |
| Identity | A `TYPE = SERVICE` user with key-pair auth and its own role | Predictable ownership of every object Sigma creates |
| Role on the connection | Set it explicitly | With the Role field blank, Sigma uses the user's default role, and that role owns everything Sigma creates |
| Write privileges | `USAGE` on the database; `USAGE, CREATE TABLE, CREATE VIEW, CREATE STAGE` on the write schema | The privileges Sigma documents for Snowflake write access |
| `QUOTED_IDENTIFIERS_IGNORE_CASE` | `FALSE` on the Sigma user (the default) | Sigma's names are mixed-case quoted identifiers. With `TRUE`, Snowflake can no longer find them and input table saves fail |
| Warehouse | A small dedicated warehouse | Every edit is a `MERGE`, and warehouse views are recreated after edits. A separate warehouse makes that cost visible |

To finish the service user created by the walkthrough, add a public key (`ALTER USER SIGMA_SERVICE_USER SET RSA_PUBLIC_KEY = '...'`), then in Sigma go to **Administration > Connections**, add a Snowflake connection with key-pair authentication, turn on **Write access**, and set the write schema to `SNOWFLAKE_EXAMPLE.SIGMA_WRITEBACK`.

**Moving to OAuth later?** Sigma then checks write access per user, and existing `SIGDS_` objects keep their old owner. Read Sigma's [migration considerations](https://community.sigmacomputing.com/t/considerations-for-migrating-from-key-pair-to-oauth-for-input-tables-and-write-back/7167) before you switch.

## Step 2: Build input tables that behave

These are Sigma-side habits that prevent most problems later.

1. **Name the element before anything else.** The warehouse view inherits the element name. An unnamed element produced a view called `NEW_INPUT_TABLE`.
2. **Set column types in Sigma.** Change `Target` to **Number** before data entry starts. Changing it later can remove values that do not fit the new type.
3. **Decide where people type.** By default an input table is **Editable in draft**, so only workbook editors can enter data. For a data-entry app, set it to **Editable in published version** and publish. The setting does not take effect until you publish.
4. **For linked input tables, choose a stable primary key.** Use a record ID or UUID. Sigma warns against dates, timestamps, row numbers, calculated values, names, and statuses, because when the key changes, the entered data stops matching and appears to be missing.

## Step 3: Create a warehouse view

In the published workbook, select the input table, then **More > Advanced options > Create warehouse view**, and keep or edit the name. The view appears in the write schema within seconds.

What the generated view does, from its SQL:

```sql
create or replace view "SIGMA_WRITEBACK"."INCOMING"."NEW_INPUT_TABLE" copy grants
  comment = 'Created by <editor> in Sigma ...'
as select SAKZ1N4J3M REGION, JQZEOOGJ6P "TARGET", "3HNOK9IT3B" NOTES
from ( ... from "SIGDS_2e4089ed_..." where ROW_VERSION <= 14
       qualify row_number() over (partition by "ID" order by ROW_VERSION desc) = 1
           and TOMBSTONE_VERSION is null )
```

It is the same "newest version, no tombstone, rename the codes" logic, written by Sigma. Behaviors observed in testing that matter for anyone depending on it:

- **It stays current, because Sigma keeps rewriting it.** The view is pinned to a version number (`ROW_VERSION <= 14`). After users entered data in the published workbook, Sigma ran `CREATE OR REPLACE VIEW` again within seconds, raised the pin, and added the newest edits as literal values in the view's SQL. A new row and a changed cell both appeared without anyone republishing.
- **The view's definition contains entered data.** Because recent edits are written into the SQL, anyone who can run `GET_DDL` or `SHOW VIEWS` on it can read those values. Restrict the write schema accordingly.
- **Filters on the element become filters on the view.** A filter that hid one region in Sigma, then a republish, removed that region from the Snowflake view. The data was still in the `SIGDS_` table. Every downstream consumer silently lost those rows.
- **It reflects the published version only.** Changes in a draft, including removing that filter, do nothing until published.
- **It is owned by the connection role** and created with `COPY GRANTS`, so grants made directly on the view survive Sigma's rewrites.

Limits Sigma documents for warehouse views: one view per element; no views on elements with column-level security or transposed tables; control values used as parameters and relative date filters are not saved into the view; a view cannot be built on another warehouse view; and if the view's owner is deactivated, the view stays tied to that user and must be deleted and recreated. If Sigma and Snowflake use different time zones, date columns can shift, and a linked input table keyed on a date can drop rows from the view.

## Step 4: Put a contract view in front of it

Treat the Sigma warehouse view as an input, not as the product. Create your own view in a schema you control (section 5 of the walkthrough):

```sql
CREATE OR REPLACE VIEW SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.REGION_TARGETS AS
SELECT
    TRIM(REGION)::VARCHAR(50)    AS REGION,
    TRY_TO_NUMBER(TARGET, 38, 2) AS TARGET_AMOUNT,
    NOTES::VARCHAR(1000)         AS NOTES
FROM SNOWFLAKE_EXAMPLE.SIGMA_WRITEBACK.REGION_TARGETS   -- the Sigma warehouse view
WHERE REGION IS NOT NULL;
```

What this buys you:

- **Real types.** `TRY_TO_NUMBER` turns text into numbers and returns NULL instead of failing on a bad entry.
- **No blank rows.** Clicking the `+` row in Sigma saves an all-NULL row. In the test it showed up in the warehouse view.
- **A stable name and shape.** If someone renames the Sigma element or recreates the warehouse view, you fix one view, not every consumer.
- **One place to grant.** Consumers get `SELECT` on this schema only (future grants in the walkthrough). The walkthrough's consumer role can read the contract view and gets "does not exist or not authorized" on the lab and write schemas.

**Use a plain view, not a dynamic table, directly on a Sigma warehouse view.** Sigma replaces the view after edits, and `CREATE OR REPLACE` on an upstream view [forces a dynamic table to reinitialize](https://docs.snowflake.com/en/user-guide/dynamic-tables/modify), which means a full rebuild, every time.

## Step 5: Keep history when you need it

The warehouse view shows only the current state. Two options for history:

| Need | Use |
| --- | --- |
| Who changed what, when | The `INPUT_TABLE_AUDIT_LOG_<id>` view Sigma creates, or add **Last updated by / at** and **Created by / at** columns to the input table |
| What the numbers were on a given date | A scheduled snapshot into your own table (section 6 of the walkthrough creates a daily task, left suspended) |

Sigma notes a short delay between a user saving and the data landing in Snowflake, so schedule snapshots with some margin, not the moment a deadline passes.

## Operate

**Inventory the write schema.** Section 7 of the walkthrough lists objects in a schema by kind (data, edit log, audit view, warehouse view) with last-changed dates. Point it at your write schema.

**Clean up deliberately.** Deleting an input table in Sigma does not delete its data in Snowflake. Old `SIGDS_` tables that never change are candidates, but confirm with the workbook owner first, and remove the warehouse view in Sigma rather than dropping it in Snowflake.

**Troubleshoot failed saves** by splitting the problem in two, as Sigma's [restore access guide](https://help.sigmacomputing.com/docs/restore-input-table-access-for-a-snowflake-connection-or-user) does: can the user's role reach the `SIGDS_` data table, and can the connection's role `INSERT` and `SELECT` on the `SIGDS_WAL_` edit log? Then check `QUOTED_IDENTIFIERS_IGNORE_CASE` on the user and account.

**Watch for secondary roles in testing.** When testing a restricted role, run `USE SECONDARY ROLES NONE` first. Otherwise your other roles can make access look broader than it is.

## Common mistakes

| Mistake | What happens | Do instead |
| --- | --- | --- |
| Building reports on `SIGDS_` tables | Breaks when Sigma changes its format, and each table has different column codes | Warehouse view plus contract view |
| Granting analysts the write schema | They see raw storage and edit logs, plus entered values in view definitions | Grant only the contract schema |
| Filtering the input table to tidy the screen | Rows disappear from the Snowflake view | Filter a child table, not the element with the warehouse view |
| Leaving the element named "New Input Table" | View called `NEW_INPUT_TABLE` | Name the element first |
| Leaving number columns as text | Stored as `TEXT` | Set the type in Sigma; cast in the contract view |
| Dynamic table directly on the warehouse view | Full rebuild after every Sigma edit | Plain view, plus scheduled snapshot if needed |
| Expecting deleted input tables to clean up | Data stays in Snowflake | Periodic inventory and owner-approved cleanup |

## What is coming: Sigma Tables

Sigma announced Sigma Tables as a public beta on 2026-11-03: shared writeback tables that live in the warehouse and that other workbooks and external systems can read and write, with Snowflake row and column policies enforced. This guide covers classic input tables, the generally available feature. Re-evaluate when Sigma Tables reach general availability.

## Learn from people who know more

- **Sigma documentation.** [Input tables overview](https://help.sigmacomputing.com/docs/intro-to-input-tables) (storage, edit log, "cannot query directly", removal), [Create and manage warehouse views](https://help.sigmacomputing.com/docs/create-and-manage-workbook-warehouse-views) (all view limits), [Create new input tables](https://help.sigmacomputing.com/docs/create-new-input-tables) (primary key guidance), [Data entry permission](https://help.sigmacomputing.com/docs/customize-data-entry-permission-on-input-tables), [Connect to Snowflake](https://help.sigmacomputing.com/docs/connect-to-snowflake).
- **Sigma community, Knowledge Hub.** [Considerations for migrating from Key-pair to OAuth for input tables](https://community.sigmacomputing.com/t/considerations-for-migrating-from-key-pair-to-oauth-for-input-tables-and-write-back/7167): the `SIGDS_` versus WAL access split, dedicated schemas, and token expiry.
- **InterWorks.** [Sigma and Snowflake sales workflow](https://interworks.com/blog/2026/06/08/sigma-and-snowflake-sales-workflow-extend-spreadsheets-with-flags-and-comment-history/) (June 2026): a warehouse view as the stable, readable object to build reporting on.
- **Atrium.** [How to configure Sigma writeback with Snowflake](https://atrium.ai/resources/how-to-configure-sigma-writeback-with-snowflake/): connection setup and a first look at the write schema.
- **Sigma QuickStarts.** [Snapshotting with stored procedures](https://quickstarts.sigmacomputing.com/guide/dataapps_snapshotting_with_sp/index.html): point-in-time copies of input table data and the save-to-landing delay.
- **Dataplatr.** [Sigma input and write-back tables explained](https://dataplatr.com/blog/sigma-input-tables): input table types and use cases.

## Related Guides

- [Snowflake identifier requirements](https://docs.snowflake.com/en/sql-reference/identifiers-syntax)
- [Modify dynamic tables (reinitialization triggers)](https://docs.snowflake.com/en/user-guide/dynamic-tables/modify)
- [USE SECONDARY ROLES](https://docs.snowflake.com/en/sql-reference/sql/use-secondary-roles)

## External References

- Sigma: [Input tables overview](https://help.sigmacomputing.com/docs/intro-to-input-tables)
- Sigma: [Create and manage warehouse views](https://help.sigmacomputing.com/docs/create-and-manage-workbook-warehouse-views)
- Sigma: [Use warehouse views with version tagging](https://help.sigmacomputing.com/docs/use-warehouse-views-with-version-tagging)
- Sigma: [Restore input table access for a Snowflake connection or user](https://help.sigmacomputing.com/docs/restore-input-table-access-for-a-snowflake-connection-or-user)
- Sigma: [About OAuth with write access](https://help.sigmacomputing.com/docs/configure-oauth-with-write-access)
- Sigma: [Introducing Sigma Tables](https://www.sigmacomputing.com/blog/introducing-sigma-tables)
- Snowflake: [CREATE USER](https://docs.snowflake.com/en/sql-reference/sql/create-user)
- Snowflake: [Key-pair authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)
- Snowflake: [Parameters: QUOTED_IDENTIFIERS_IGNORE_CASE](https://docs.snowflake.com/en/sql-reference/parameters#quoted-identifiers-ignore-case)
