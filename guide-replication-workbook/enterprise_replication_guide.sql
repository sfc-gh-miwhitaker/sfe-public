/*******************************************************************************
 * ENTERPRISE REPLICATION GUIDE
 * Basic Redundancy with Replication Groups (Read-Only)
 *
 * Purpose: Create read-only replicas of databases across Snowflake accounts
 * Edition: Works on Standard and Enterprise editions
 *
 * WHAT THIS GUIDE COVERS:
 * - Replication groups for databases (and optionally shares)
 * - Scheduled refresh (RPO)
 * - Creating secondary replication groups in target accounts
 * - Manual refresh and monitoring (progress/history/usage)
 *
 * WHAT THIS GUIDE DOES NOT COVER:
 * - Failover groups and promotion (Business Critical edition only)
 * - Replicating account objects beyond databases/shares (Business Critical only)
 *
 * For business continuity/failover capabilities, see:
 * - business_critical_business_continuity_guide.sql
 ******************************************************************************/


/*******************************************************************************
 * PREREQUISITES CHECKLIST
 ******************************************************************************/

-- Account prerequisites:
-- [ ] Source and target accounts are in the same Snowflake organization
-- [ ] ORGADMIN has enabled replication for both accounts
-- [ ] In the source account, you have a role with:
--     - CREATE REPLICATION GROUP on the account (ACCOUNTADMIN has this by default)
--     - MONITOR on each database you plan to include
-- [ ] If replicating shares, you have OWNERSHIP on each share

-- Database prerequisites:
-- [ ] Databases to replicate are not created from a share
-- [ ] Databases are permanent or transient (not temporary)
-- [ ] You understand replicas in target accounts are read-only (basic redundancy)

-- Network / region prerequisites:
-- [ ] Target accounts can receive replication traffic
-- [ ] If replicating across regions/clouds, those regions are supported

-- Business Critical-only capabilities (not covered here):
-- - Failover groups / promotion to primary
-- - Replication of users/roles/warehouses/network policies/account parameters


/*******************************************************************************
 * UNDERSTANDING SNOWFLAKE ACCOUNT IDENTIFIERS
 ******************************************************************************/

-- Snowflake uses a specific format to identify accounts across an organization:
--
--   FORMAT: <organization_name>.<account_name>
--
-- EXAMPLE BREAKDOWN:
--   ACME_CORP.PROD_US_EAST     →  Organization: ACME_CORP, Account: PROD_US_EAST
--   ACME_CORP.DR_US_WEST       →  Organization: ACME_CORP, Account: DR_US_WEST
--   GLOBEX.SALES_ANALYTICS     →  Organization: GLOBEX,     Account: SALES_ANALYTICS
--
-- WHERE TO FIND THESE VALUES:
--   1. Run SHOW REPLICATION ACCOUNTS (see Step 1 below)
--   2. Look at the 'organization_name' column  →  This is your <organization_name>
--   3. Look at the 'account_name' column       →  This is your <account_name>
--   4. Combine them with a dot: <organization_name>.<account_name>
--
-- REAL-WORLD EXAMPLE:
--   If SHOW REPLICATION ACCOUNTS returns:
--     | organization_name | account_name     | snowflake_region |
--     |-------------------|------------------|------------------|
--     | ACME_CORP         | PROD_US_EAST     | AWS_US_EAST_1   |
--     | ACME_CORP         | DR_US_WEST       | AWS_US_WEST_2   |
--
--   You would use:
--     - ACME_CORP.PROD_US_EAST (for production account)
--     - ACME_CORP.DR_US_WEST   (for disaster recovery account)


/*******************************************************************************
 * STEP 1: DISCOVER REPLICATION-ENABLED ACCOUNTS
 *
 * Run in: SOURCE account
 * Purpose: Identify which accounts in your organization are enabled for replication
 ******************************************************************************/

-- View all replication-enabled accounts in your organization
-- PAY ATTENTION TO: organization_name and account_name columns
SHOW REPLICATION ACCOUNTS;

-- Example output:
-- | organization_name | account_name     | snowflake_region | account_locator | ...
-- |-------------------|------------------|------------------|-----------------|----
-- | ACME_CORP         | PROD_US_EAST     | AWS_US_EAST_1    | ABC12345        | ...
-- | ACME_CORP         | DR_US_WEST       | AWS_US_WEST_2    | XYZ67890        | ...

-- 📋 Checklist: Account Discovery
-- [ ] All target accounts appear in the list above
-- [ ] Write down the organization_name (same for all accounts in your org)
-- [ ] Write down the account_name for each target account
-- [ ] Verify regions support your replication requirements


/*******************************************************************************
 * STEP 2: CREATE A REPLICATION GROUP (PRIMARY)
 *
 * Run in: SOURCE account
 * Purpose: Define which objects to replicate and which accounts can receive them
 ******************************************************************************/

-- 🔧 CONFIGURATION GUIDE:
--
-- 1. REPLICATION GROUP NAME:
--    Choose a descriptive name (e.g., PROD_DATABASES_RG, SALES_DATA_REPLICATION)
--
-- 2. ALLOWED_DATABASES:
--    List the database(s) you want to replicate
--    Examples: (SALES_DB)  or  (SALES_DB, MARKETING_DB, FINANCE_DB)
--
-- 3. ALLOWED_ACCOUNTS:
--    Use the format: <organization_name>.<account_name> from SHOW REPLICATION ACCOUNTS
--
--    EXAMPLE - If your SHOW REPLICATION ACCOUNTS showed:
--      organization_name = ACME_CORP
--      account_name = DR_US_WEST
--    Then use: ACME_CORP.DR_US_WEST
--
--    For multiple accounts:
--      (ACME_CORP.DR_US_WEST, ACME_CORP.DR_EUROPE)
--
-- 4. REPLICATION_SCHEDULE:
--    How often to refresh (your RPO)
--    Examples: '5 MINUTE', '10 MINUTE', '1 HOUR', '1 DAY'

-- EXAMPLE with real-world names:
-- CREATE REPLICATION GROUP IF NOT EXISTS PROD_DATABASES_RG
--   OBJECT_TYPES = DATABASES
--   ALLOWED_DATABASES = (SALES_DB, INVENTORY_DB)
--   ALLOWED_ACCOUNTS = (ACME_CORP.DR_US_WEST, ACME_CORP.DR_EUROPE)
--   REPLICATION_SCHEDULE = '10 MINUTE';

-- 👉 REPLACE THE VALUES BELOW WITH YOUR ACTUAL VALUES:
CREATE REPLICATION GROUP IF NOT EXISTS MY_REPLICATION_GROUP
  OBJECT_TYPES = DATABASES
  ALLOWED_DATABASES = (MYDB)  -- Replace MYDB with your database name(s)
  ALLOWED_ACCOUNTS = (YOUR_ORG.YOUR_TARGET_ACCOUNT)  -- Replace with values from SHOW REPLICATION ACCOUNTS above
  REPLICATION_SCHEDULE = '10 MINUTE';  -- Adjust frequency to match your RPO

-- 📋 Checklist: Replication Group Creation
-- [ ] Replication group created without errors
-- [ ] Replication schedule configured (adjust '10 MINUTE' to your RPO)
-- [ ] All target accounts are specified
-- [ ] All databases to replicate are included


/*******************************************************************************
 * STEP 3: BUSINESS CONTINUITY NOTE
 *
 * This guide intentionally stops at read-only replicas (basic redundancy).
 *
 * If you need the ability to PROMOTE a target account to become primary
 * (read-write) during an outage, you must use FAILOVER GROUPS
 * (Business Critical edition or higher).
 *
 * See: business_critical_business_continuity_guide.sql
 ******************************************************************************/

-- 📋 Checklist: If you need failover
-- [ ] Confirm the account is Business Critical (or higher)
-- [ ] Use the Business Critical guide to create a FAILOVER GROUP
-- [ ] Test promotion procedures
-- [ ] Document RPO/RTO and the operational failover runbook


/*******************************************************************************
 * STEP 4: VERIFY REPLICATION GROUP CONFIGURATION
 *
 * Run in: SOURCE account
 * Purpose: Verify the replication group was created correctly
 ******************************************************************************/

-- View all replication groups in this account
SHOW REPLICATION GROUPS;

-- View a specific replication group
SHOW REPLICATION GROUPS LIKE 'MY_REPLICATION_GROUP';

-- View databases included in the replication group
SHOW DATABASES IN REPLICATION GROUP MY_REPLICATION_GROUP;

-- 📋 Checklist: Verification
-- [ ] Replication group appears in SHOW output
-- [ ] Primary databases are listed
-- [ ] Allowed accounts match your configuration
-- [ ] Replication schedule is correct


/*******************************************************************************
 * STEP 5: CREATE SECONDARY REPLICATION GROUP
 *
 * Run in: TARGET account(s)
 * Purpose: Create the read-only replicas in each target account
 *
 * IMPORTANT NOTES:
 * - Sign in to the TARGET account before running
 * - Use the same group name as in the source (recommended)
 * - The source identifier format: <org_name>.<source_account_name>.<group_name>
 ******************************************************************************/

-- 🔧 CONFIGURATION GUIDE:
--
-- The "AS REPLICA OF" clause needs the FULL identifier of the source group:
--   <organization_name>.<source_account_name>.<replication_group_name>
--
-- EXAMPLE - If you have:
--   - Organization: ACME_CORP
--   - Source account: PROD_US_EAST
--   - Replication group: PROD_DATABASES_RG
--
-- Then use: ACME_CORP.PROD_US_EAST.PROD_DATABASES_RG
--
-- HOW TO FIND THESE VALUES:
--   1. organization_name → From SHOW REPLICATION ACCOUNTS in SOURCE account
--   2. source_account_name → The account_name of your SOURCE account
--   3. replication_group_name → The name you created in Step 2

-- EXAMPLE with real-world names:
-- CREATE REPLICATION GROUP IF NOT EXISTS PROD_DATABASES_RG
--   AS REPLICA OF ACME_CORP.PROD_US_EAST.PROD_DATABASES_RG;

-- 👉 REPLACE THE VALUES BELOW:
CREATE REPLICATION GROUP IF NOT EXISTS MY_REPLICATION_GROUP
  AS REPLICA OF YOUR_ORG.YOUR_SOURCE_ACCOUNT.MY_REPLICATION_GROUP;

-- 📋 Checklist: Secondary Replication Group Creation
-- [ ] Secondary replication group created in each target account
-- [ ] Secondary group name matches the primary group name (recommended)
-- [ ] Initial refresh completed successfully (automatic on creation)


/*******************************************************************************
 * STEP 6: MANUAL REFRESH (OPTIONAL)
 *
 * Run in: TARGET account
 * Purpose: Force an immediate refresh for validation or troubleshooting
 *
 * NOTE: If REPLICATION_SCHEDULE is set on the primary group, refreshes
 *       happen automatically. Manual refresh is only needed for testing
 *       or troubleshooting.
 ******************************************************************************/

-- Optional: Increase timeout for large refreshes
-- ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 604800;

-- Manually refresh the secondary replication group
ALTER REPLICATION GROUP MY_REPLICATION_GROUP REFRESH;

-- 📋 Checklist: Manual Refresh
-- [ ] ALTER REPLICATION GROUP ... REFRESH executed successfully
-- [ ] No timeout errors (increase statement timeout if needed)
-- [ ] Refresh progress/history show SUCCEEDED phases


/*******************************************************************************
 * STEP 7: MONITOR REFRESH PROGRESS
 *
 * Run in: TARGET account
 * Purpose: Track the status of refresh operations
 * Retention: Last 14 days
 ******************************************************************************/

-- View refresh progress for the most recent refresh
SELECT
    phase_name,
    start_time,
    end_time,
    progress,
    details
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_PROGRESS('MY_REPLICATION_GROUP'))
ORDER BY start_time DESC;

-- 📋 Checklist: Progress Monitoring
-- [ ] Refresh phases are visible for the secondary group
-- [ ] Latest refresh ends in COMPLETED / SUCCEEDED
-- [ ] end_time is populated for completed phases
-- [ ] progress reaches 100% for long-running phases


/*******************************************************************************
 * STEP 8: VIEW REFRESH HISTORY
 *
 * Run in: TARGET account
 * Purpose: Review past refresh operations
 * Retention: Last 14 days
 ******************************************************************************/

-- View refresh history (last 20 refreshes)
SELECT
    phase_name,
    start_time,
    end_time,
    total_bytes,
    object_count
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('MY_REPLICATION_GROUP'))
ORDER BY start_time DESC
LIMIT 20;

-- 📋 Checklist: History Review
-- [ ] Historical refreshes completed successfully
-- [ ] No recurring failures
-- [ ] Refresh frequency matches your RPO requirements
-- [ ] Total bytes / object counts look reasonable for your databases


/*******************************************************************************
 * STEP 9: MONITOR USAGE (CREDITS AND BYTES)
 *
 * Run in: TARGET account
 * Purpose: Track replication costs
 * Retention: Last 14 days
 *
 * NOTE: For longer retention, use Account Usage or Organization Usage views
 ******************************************************************************/

-- View replication group usage (last 14 days)
SELECT
  start_time,
  end_time,
  replication_group_name,
  credits_used,
  bytes_transferred,
  bytes_transferred / 1024 / 1024 / 1024 AS gb_transferred
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_USAGE_HISTORY(
  date_range_start => DATEADD('day', -14, CURRENT_TIMESTAMP()),
  replication_group_name => 'MY_REPLICATION_GROUP'
))
ORDER BY start_time DESC;

-- Calculate total usage over the window
SELECT
  SUM(credits_used) AS total_credits,
  SUM(bytes_transferred) / 1024 / 1024 / 1024 AS total_gb_transferred
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_USAGE_HISTORY(
  date_range_start => DATEADD('day', -14, CURRENT_TIMESTAMP()),
  replication_group_name => 'MY_REPLICATION_GROUP'
));

-- 📋 Checklist: Cost Monitoring
-- [ ] Replication costs are within budget
-- [ ] No unexpected spikes in data transfer
-- [ ] Credit usage trends are acceptable
-- [ ] Cost monitoring alerts configured (optional)


/*******************************************************************************
 * STEP 10: VALIDATE DATA CONSISTENCY (OPTIONAL)
 *
 * Purpose: Verify data matches between primary and secondary using HASH_AGG
 ******************************************************************************/

-- STEP 1: Run in TARGET account to get the primary snapshot timestamp
SELECT PARSE_JSON(details)['primarySnapshotTimestamp'] AS primary_snapshot_ts
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_PROGRESS('MY_REPLICATION_GROUP'))
WHERE phase_name = 'PRIMARY_UPLOADING_METADATA';

-- STEP 2: Run in TARGET account to hash the replicated table
-- SELECT HASH_AGG(*) FROM <db>.<schema>.<table>;

-- STEP 3: Run in SOURCE account to hash the primary table at the snapshot timestamp
-- SELECT HASH_AGG(*) FROM <db>.<schema>.<table>
--   AT(TIMESTAMP => '<primarySnapshotTimestamp>'::TIMESTAMP);

-- STEP 4: Compare the hash values from STEP 2 and STEP 3 - they should match exactly

-- 📋 Checklist: Data Validation
-- [ ] Sample tables selected for validation
-- [ ] Hash values match between primary and secondary
-- [ ] Row counts verified
-- [ ] Critical data validated


/*******************************************************************************
 * STEP 11: CONFIGURE REPLICATION SCHEDULE
 *
 * Purpose: Set or change the automatic refresh schedule
 *
 * NOTES:
 * - Set the schedule in the SOURCE account on the primary group
 * - In TARGET accounts, you can pause/resume with SUSPEND/RESUME
 * - Tasks are typically unnecessary for basic redundancy
 ******************************************************************************/

-- Run in SOURCE account: Change the replication schedule
ALTER REPLICATION GROUP MY_REPLICATION_GROUP SET
  REPLICATION_SCHEDULE = '10 MINUTE';

-- Run in TARGET account: Suspend scheduled replication
ALTER REPLICATION GROUP MY_REPLICATION_GROUP SUSPEND;

-- Run in TARGET account: Resume scheduled replication
ALTER REPLICATION GROUP MY_REPLICATION_GROUP RESUME;

-- 📋 Checklist: Replication Schedule
-- [ ] REPLICATION_SCHEDULE is configured on the primary group
-- [ ] Schedule matches RPO requirements
-- [ ] Target accounts are receiving refreshes on the expected cadence
-- [ ] You can suspend/resume scheduled refresh in target accounts when needed


/*******************************************************************************
 * STEP 12: CHECK REPLICATION GROUP STATUS
 *
 * Run in: SOURCE or TARGET account
 * Purpose: Verify schedule state, next refresh, and primary/secondary status
 ******************************************************************************/

-- View detailed status of a replication group
SHOW REPLICATION GROUPS LIKE 'MY_REPLICATION_GROUP';

-- Key columns to check:
-- - name: Replication group name
-- - type: DATABASES
-- - is_primary: TRUE (source) or FALSE (target)
-- - primary: The source account identifier (visible in target accounts)
-- - allowed_accounts: Target accounts (visible in source account)
-- - replication_schedule: Refresh frequency
-- - secondary_state: Status in target account
-- - next_scheduled_refresh: Next automatic refresh time

-- 📋 Checklist: Ongoing Monitoring
-- [ ] Refreshes are succeeding on schedule
-- [ ] No recurring failures in refresh history
-- [ ] Duration and transferred bytes are within expected ranges
-- [ ] Alerts exist for refresh failures (optional)


/*******************************************************************************
 * TROUBLESHOOTING GUIDE
 ******************************************************************************/

-- Issue: "Account not enabled for replication"
-- Solution:
-- - Confirm both accounts are in the same organization
-- - Have ORGADMIN enable replication for the accounts

-- Issue: "Database cannot be replicated" / "Database missing from group"
-- Solution:
-- - Confirm the database is not created from a share
-- - Confirm the role creating the group has MONITOR on the database
-- - Confirm the database does not contain unsupported objects for replication

-- Issue: "Timeout during a refresh"
-- Solution:
ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 604800;

-- Issue: "Scheduled refresh not running"
-- Solution:
-- - In SOURCE account, confirm REPLICATION_SCHEDULE is set
-- - In TARGET account, confirm scheduled refresh is not suspended
-- - Ensure the group owner role has required privileges

-- Issue: "High replication costs"
-- Solution:
-- - Increase the refresh interval
-- - Reduce the number/size of databases in the group
-- - Use INFORMATION_SCHEMA.REPLICATION_GROUP_USAGE_HISTORY to quantify costs

-- Issue: "Refresh fails"
-- Solution:
-- - Use INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_PROGRESS for phase-level details
-- - Check for dangling references:
SELECT * FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_DANGLING_REFERENCES('MY_REPLICATION_GROUP'));
-- - Run a manual refresh to retry


/*******************************************************************************
 * BEST PRACTICES
 ******************************************************************************/

-- 1. NAMING
-- - Name replication groups clearly (e.g., PROD_REDUNDANCY_RG)
-- - Use the same replication group name in source and target accounts
-- - Document the primary group identifier (<org>.<account>.<group>)

-- 2. SCHEDULING (RPO)
-- - Match refresh frequency to your RPO
-- - Avoid over-frequent refreshes if not needed (cost optimization)

-- 3. MONITORING
-- - Use INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_PROGRESS (current/recent)
-- - Use INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY (last 14 days)
-- - Use INFORMATION_SCHEMA.REPLICATION_GROUP_USAGE_HISTORY (credits/bytes, last 14 days)
-- - Add alerts for failed refreshes (optional)

-- 4. SECURITY AND ACCESS CONTROL
-- Use least privilege:
-- - CREATE REPLICATION GROUP on the account (or ACCOUNTADMIN)
-- - MONITOR on each database you include
-- - REPLICATE on the group for roles that need to refresh a secondary group

-- 5. PERFORMANCE AND RELIABILITY
-- - Increase statement timeout for large refreshes when needed
-- - Keep the group focused (only replicate what you actually need)

-- 6. DOCUMENTATION
-- - Maintain a list of replicated databases and target accounts
-- - Document the intended RPO and monitoring approach
-- - Keep a short runbook for manual refresh and common failure modes


/*******************************************************************************
 * FINAL CHECKLIST
 ******************************************************************************/

-- Configuration:
-- [ ] All target accounts identified and enabled for replication
-- [ ] Primary replication group created with correct settings
-- [ ] Secondary replication group created in each target account
-- [ ] Scheduled refresh configured (or explicitly omitted) on the primary group

-- Verification:
-- [ ] Manual refresh tested at least once in a target account
-- [ ] Refresh progress/history show successful completion
-- [ ] Usage history (credits/bytes) is visible for the secondary group

-- Documentation and Operations:
-- [ ] Replication architecture documented (accounts, databases, schedule)
-- [ ] Contact list and access model documented
-- [ ] Runbook exists for manual refresh and common failure modes
-- [ ] Team knows where to monitor refreshes and usage


/*******************************************************************************
 * ADDITIONAL RESOURCES
 ******************************************************************************/

-- Snowflake Documentation:
-- - https://docs.snowflake.com/en/user-guide/account-replication-intro
-- - https://docs.snowflake.com/en/user-guide/account-replication-config

-- Key SQL Commands (Replication Groups):
-- - SHOW REPLICATION ACCOUNTS
-- - CREATE REPLICATION GROUP
-- - ALTER REPLICATION GROUP
-- - DROP REPLICATION GROUP
-- - SHOW REPLICATION GROUPS
-- - SHOW DATABASES IN REPLICATION GROUP <group_name>

-- Monitoring (Information Schema Table Functions):
-- - INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_PROGRESS('<secondary_group_name>')
-- - INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('<secondary_group_name>')
-- - INFORMATION_SCHEMA.REPLICATION_GROUP_USAGE_HISTORY(...)
-- - INFORMATION_SCHEMA.REPLICATION_GROUP_DANGLING_REFERENCES('<group_name>')

-- Business Continuity (Business Critical):
-- For failover groups and promotion, see:
-- - business_critical_business_continuity_guide.sql


/*******************************************************************************
 * CLEANUP (OPTIONAL)
 *
 * WARNING: Dropping groups changes replica protection semantics
 * - Dropping a secondary replication group can make replicated databases
 *   writable in the target account
 * - A primary replication group cannot be dropped until all linked secondary
 *   groups are dropped
 ******************************************************************************/

-- Step 1: Drop secondary replication groups in TARGET accounts first
-- DROP REPLICATION GROUP IF EXISTS MY_REPLICATION_GROUP;

-- Step 2: After all secondary groups are dropped, drop primary in SOURCE account
-- DROP REPLICATION GROUP IF EXISTS MY_REPLICATION_GROUP;


/*******************************************************************************
 * END OF GUIDE
 ******************************************************************************/
