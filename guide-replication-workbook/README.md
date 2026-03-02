# Replication Workbook (SQL Guides)

This folder contains SQL guides for setting up Snowflake replication:

- `enterprise_replication_guide.sql` - **Enterprise/Standard**: basic redundancy with replication groups (read-only replicas; no promotion)
- `business_critical_failover_guide.sql` - **Business Critical**: business continuity with failover groups (promotion/runbook)
- `account_setup_prerequisite_guide.sql` - Prerequisites and account setup

## Which guide should I use?

- **Basic redundancy (read-only replicas)**: use `enterprise_replication_guide.sql`
- **Business continuity (promotion / failover)**: use `business_critical_failover_guide.sql`

## Prerequisites

- You can sign in to Snowsight for your Snowflake account.
- Your active role has appropriate privileges for replication setup (typically ACCOUNTADMIN or a role with CREATE REPLICATION GROUP).

## How to use these guides

### Option 1: Snowsight Worksheet (Recommended)

1. Sign in to Snowsight.
2. Create a new **SQL Worksheet**.
3. Copy/paste the contents of the relevant `.sql` file.
4. Run the statements step by step, following the comments.

### Option 2: Download and run locally

If you already have this repository checked out locally, the SQL files are in this folder.

Otherwise, download from GitHub:

1. Open the SQL file in GitHub:
   - `tools/replication-workbook/enterprise_replication_guide.sql`, or
   - `tools/replication-workbook/business_critical_failover_guide.sql`
2. Download the file to your computer (the exact UI varies; "Download raw file" is common).

Alternative: Download the repository as a ZIP (GitHub: Code -> Download ZIP), unzip it, then find:

- `tools/replication-workbook/enterprise_replication_guide.sql`
- `tools/replication-workbook/business_critical_failover_guide.sql`

## Notes / common issues

- **Permission errors**: Switch to a role with the needed privileges (ACCOUNTADMIN or role with CREATE REPLICATION GROUP), then re-try.
- **Cross-region replication**: Ensure both accounts are in the same organization and replication is enabled.

## References

- [Replication and Failover Groups](https://docs.snowflake.com/en/user-guide/replication-intro)
- [CREATE REPLICATION GROUP](https://docs.snowflake.com/en/sql-reference/sql/create-replication-group)
