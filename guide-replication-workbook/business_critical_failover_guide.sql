/*******************************************************************************
 * BUSINESS CRITICAL FAILOVER GUIDE
 * Complete Business Continuity with Failover Groups
 *
 * Purpose: Enable full business continuity with failover and promotion capabilities
 * Edition: Business Critical (or higher) ONLY
 *
 * WHAT THIS GUIDE COVERS:
 * - Failover groups for complete business continuity
 * - Replication of databases AND account objects (users, roles, warehouses, etc.)
 * - Failover/promotion: Make a secondary account become primary (read-write)
 * - Testing failover procedures
 * - Failback procedures: Reverting to original primary after recovery
 * - Client redirect for seamless connection failover
 *
 * WHAT THIS GUIDE DOES NOT COVER:
 * - Basic redundancy with read-only replicas (see: enterprise_replication_guide.sql)
 *
 * KEY DIFFERENCES FROM ENTERPRISE EDITION:
 * - FAILOVER GROUPS (not replication groups)
 * - Can promote secondary to become primary (read-write)
 * - Replicates account objects: users, roles, warehouses, resource monitors, etc.
 * - Enables true disaster recovery and business continuity
 ******************************************************************************/


/*******************************************************************************
 * PREREQUISITES CHECKLIST
 ******************************************************************************/

-- Account prerequisites:
-- [ ] ALL accounts are Business Critical edition (or higher)
-- [ ] Source and target accounts are in the same Snowflake organization
-- [ ] ORGADMIN has enabled replication for all accounts
-- [ ] In the source account, you have ACCOUNTADMIN or a role with:
--     - CREATE FAILOVER GROUP on the account
--     - MONITOR on each database you plan to include
--     - OWNERSHIP on each share you plan to include (if replicating shares)

-- Database prerequisites:
-- [ ] Databases to replicate are not created from a share
-- [ ] Databases are permanent or transient (not temporary)

-- Business continuity prerequisites:
-- [ ] You have documented RTO (Recovery Time Objective) requirements
-- [ ] You have documented RPO (Recovery Point Objective) requirements
-- [ ] You have a failover runbook and team contact list
-- [ ] You understand failover testing procedures

-- Network / region prerequisites:
-- [ ] Target accounts can receive replication traffic
-- [ ] If replicating across regions/clouds, those regions are supported

-- IMPORTANT: Business Critical Edition Required
-- This guide requires Business Critical (or higher). Failover groups and
-- promotion capabilities are NOT available in Standard or Enterprise editions.


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
--   GLOBEX.ANALYTICS_BACKUP    →  Organization: GLOBEX,     Account: ANALYTICS_BACKUP
--
-- WHERE TO FIND THESE VALUES:
--   1. Run SHOW REPLICATION ACCOUNTS (see Step 1 below)
--   2. Look at the 'organization_name' column  →  This is your <organization_name>
--   3. Look at the 'account_name' column       →  This is your <account_name>
--   4. Combine them with a dot: <organization_name>.<account_name>
--
-- REAL-WORLD EXAMPLE:
--   If SHOW REPLICATION ACCOUNTS returns:
--     | organization_name | account_name     | snowflake_region | edition           |
--     |-------------------|------------------|------------------|-------------------|
--     | ACME_CORP         | PROD_US_EAST     | AWS_US_EAST_1   | BUSINESS_CRITICAL |
--     | ACME_CORP         | DR_US_WEST       | AWS_US_WEST_2   | BUSINESS_CRITICAL |
--
--   You would use:
--     - ACME_CORP.PROD_US_EAST (for production primary account)
--     - ACME_CORP.DR_US_WEST   (for disaster recovery failover account)


/*******************************************************************************
 * STEP 1: DISCOVER REPLICATION-ENABLED ACCOUNTS
 *
 * Run in: SOURCE account (primary)
 * Purpose: Identify accounts enabled for replication and verify Business Critical edition
 ******************************************************************************/

-- View all replication-enabled accounts in your organization
-- PAY ATTENTION TO: organization_name, account_name, and edition columns
SHOW REPLICATION ACCOUNTS;

-- Example output:
-- | organization_name | account_name     | snowflake_region | edition           | ...
-- |-------------------|------------------|------------------|-------------------|----
-- | ACME_CORP         | PROD_US_EAST     | AWS_US_EAST_1    | BUSINESS_CRITICAL | ...
-- | ACME_CORP         | DR_US_WEST       | AWS_US_WEST_2    | BUSINESS_CRITICAL | ...

-- 📋 Checklist: Account Discovery
-- [ ] All accounts show edition = BUSINESS_CRITICAL (or higher)
-- [ ] All target accounts appear in the list
-- [ ] Write down the organization_name (same for all accounts)
-- [ ] Write down the account_name for each target failover account
-- [ ] Verify regions match your DR strategy


/*******************************************************************************
 * STEP 2: PLAN YOUR FAILOVER GROUP STRATEGY
 *
 * Purpose: Decide what to replicate and how to organize failover groups
 ******************************************************************************/

-- STRATEGY CONSIDERATIONS:
--
-- 1. SINGLE FAILOVER GROUP (Recommended for most cases):
--    - Replicate everything together (databases + account objects)
--    - Simplest to manage
--    - All objects fail over together as a unit
--    - Best for complete account-level DR
--
-- 2. MULTIPLE FAILOVER GROUPS:
--    - Separate databases from account objects
--    - Different refresh schedules for different data criticality
--    - More complex to manage during failover
--    - Use only if you have specific RPO requirements per database
--
-- OBJECTS YOU CAN REPLICATE:
--   - DATABASES: Your data (tables, views, stages, etc.)
--   - USERS: All user accounts
--   - ROLES: All roles and role hierarchies
--   - WAREHOUSES: All compute warehouses
--   - RESOURCE MONITORS: Credit monitoring and alerts
--   - INTEGRATIONS: Security, API, storage, external access integrations
--   - NETWORK POLICIES: Network access controls
--   - ACCOUNT PARAMETERS: All account-level settings
--   - SHARES: Outbound shares (if applicable)

-- 📋 Checklist: Planning
-- [ ] Decide on single vs multiple failover groups
-- [ ] List all databases to replicate
-- [ ] Confirm you need account objects (users, roles, warehouses)
-- [ ] Determine refresh schedule (RPO)
-- [ ] Document your DR strategy


/*******************************************************************************
 * STEP 3: CREATE A FAILOVER GROUP (PRIMARY)
 *
 * Run in: SOURCE account (primary)
 * Purpose: Define objects to replicate and enable failover capability
 ******************************************************************************/

-- 🔧 CONFIGURATION GUIDE:
--
-- 1. FAILOVER GROUP NAME:
--    Choose a name that reflects its purpose
--    Examples: PRIMARY_FAILOVER_GROUP, DR_FAILOVER_GROUP, PROD_BC_GROUP
--
-- 2. OBJECT_TYPES:
--    List the types of objects to replicate
--
--    COMPLETE DR EXAMPLE (replicate everything):
--      OBJECT_TYPES = ACCOUNT PARAMETERS, DATABASES, INTEGRATIONS,
--                     NETWORK POLICIES, RESOURCE MONITORS, ROLES, USERS, WAREHOUSES
--
--    DATABASES ONLY EXAMPLE:
--      OBJECT_TYPES = DATABASES
--
-- 3. ALLOWED_DATABASES:
--    Required if DATABASES is in OBJECT_TYPES
--    Examples: (PROD_DB)  or  (SALES_DB, FINANCE_DB, ANALYTICS_DB)
--
-- 4. ALLOWED_INTEGRATION_TYPES:
--    Required if INTEGRATIONS is in OBJECT_TYPES
--    Examples: (SECURITY INTEGRATIONS, API INTEGRATIONS, STORAGE INTEGRATIONS)
--
-- 5. ALLOWED_ACCOUNTS:
--    Target accounts that can become the new primary during failover
--    Format: <organization_name>.<account_name>
--
--    EXAMPLE from SHOW REPLICATION ACCOUNTS:
--      organization_name = ACME_CORP
--      account_name = DR_US_WEST
--    Use: ACME_CORP.DR_US_WEST
--
-- 6. REPLICATION_SCHEDULE:
--    How often to refresh (your RPO)
--    Examples: '5 MINUTE', '10 MINUTE', '1 HOUR'

-- EXAMPLE 1: Complete Business Continuity (Everything)
-- This replicates ALL account objects for full DR capability
-- CREATE FAILOVER GROUP IF NOT EXISTS COMPLETE_DR_GROUP
--   OBJECT_TYPES = ACCOUNT PARAMETERS, DATABASES, INTEGRATIONS,
--                  NETWORK POLICIES, RESOURCE MONITORS, ROLES, USERS, WAREHOUSES
--   ALLOWED_DATABASES = (PROD_DB, SALES_DB, ANALYTICS_DB)
--   ALLOWED_INTEGRATION_TYPES = (SECURITY INTEGRATIONS, API INTEGRATIONS, STORAGE INTEGRATIONS)
--   ALLOWED_ACCOUNTS = (ACME_CORP.DR_US_WEST, ACME_CORP.DR_EUROPE)
--   REPLICATION_SCHEDULE = '10 MINUTE';

-- EXAMPLE 2: Databases Only with Account Objects
-- This replicates databases plus the account objects needed to access them
-- CREATE FAILOVER GROUP IF NOT EXISTS DATABASE_DR_GROUP
--   OBJECT_TYPES = DATABASES, USERS, ROLES, WAREHOUSES
--   ALLOWED_DATABASES = (PROD_DB, SALES_DB)
--   ALLOWED_ACCOUNTS = (ACME_CORP.DR_US_WEST)
--   REPLICATION_SCHEDULE = '10 MINUTE';

-- 👉 REPLACE THE VALUES BELOW WITH YOUR ACTUAL CONFIGURATION:
CREATE FAILOVER GROUP IF NOT EXISTS MY_FAILOVER_GROUP
  OBJECT_TYPES = DATABASES, USERS, ROLES, WAREHOUSES  -- Adjust based on your needs
  ALLOWED_DATABASES = (MYDB)  -- Replace with your database names
  ALLOWED_ACCOUNTS = (YOUR_ORG.YOUR_DR_ACCOUNT)  -- Replace with values from SHOW REPLICATION ACCOUNTS
  REPLICATION_SCHEDULE = '10 MINUTE';  -- Adjust to your RPO

-- 📋 Checklist: Primary Failover Group Creation
-- [ ] Failover group created without errors
-- [ ] All required object types are included
-- [ ] All databases are listed in ALLOWED_DATABASES
-- [ ] All target DR accounts are listed in ALLOWED_ACCOUNTS
-- [ ] Replication schedule matches your RPO


/*******************************************************************************
 * STEP 4: VERIFY FAILOVER GROUP CONFIGURATION
 *
 * Run in: SOURCE account (primary)
 * Purpose: Verify the failover group was created correctly
 ******************************************************************************/

-- View all failover groups in this account
SHOW FAILOVER GROUPS;

-- View a specific failover group with details
SHOW FAILOVER GROUPS LIKE 'MY_FAILOVER_GROUP';

-- Key columns to verify:
-- - name: Failover group name
-- - type: Should be "FAILOVER"
-- - object_types: List of object types being replicated
-- - allowed_accounts: Target accounts
-- - replication_schedule: Refresh frequency
-- - is_primary: Should be TRUE in source account

-- View databases included in the failover group
SHOW DATABASES IN FAILOVER GROUP MY_FAILOVER_GROUP;

-- 📋 Checklist: Verification
-- [ ] Failover group appears with type = "FAILOVER"
-- [ ] is_primary = TRUE
-- [ ] All databases are listed
-- [ ] Allowed accounts match your configuration
-- [ ] Replication schedule is correct


/*******************************************************************************
 * STEP 5: CREATE SECONDARY FAILOVER GROUP
 *
 * Run in: TARGET account (DR/failover account)
 * Purpose: Create the failover replica in the DR account
 *
 * IMPORTANT:
 * - Sign in to the TARGET (DR) account before running
 * - Use the same group name as primary (recommended)
 * - The source identifier format: <org_name>.<source_account_name>.<group_name>
 ******************************************************************************/

-- 🔧 CONFIGURATION GUIDE:
--
-- The "AS REPLICA OF" clause needs the FULL identifier of the primary group:
--   <organization_name>.<source_account_name>.<failover_group_name>
--
-- EXAMPLE - If you have:
--   - Organization: ACME_CORP
--   - Source account: PROD_US_EAST
--   - Failover group: COMPLETE_DR_GROUP
--
-- Then use: ACME_CORP.PROD_US_EAST.COMPLETE_DR_GROUP
--
-- HOW TO FIND THESE VALUES:
--   1. organization_name → From SHOW REPLICATION ACCOUNTS in SOURCE account
--   2. source_account_name → The account_name of your PRIMARY account
--   3. failover_group_name → The name you created in Step 3

-- EXAMPLE with real-world names:
-- CREATE FAILOVER GROUP IF NOT EXISTS COMPLETE_DR_GROUP
--   AS REPLICA OF ACME_CORP.PROD_US_EAST.COMPLETE_DR_GROUP;

-- 👉 REPLACE THE VALUES BELOW:
CREATE FAILOVER GROUP IF NOT EXISTS MY_FAILOVER_GROUP
  AS REPLICA OF YOUR_ORG.YOUR_SOURCE_ACCOUNT.MY_FAILOVER_GROUP;

-- NOTE: Initial refresh happens automatically after creation
-- This may take several minutes to hours depending on data volume

-- 📋 Checklist: Secondary Failover Group Creation
-- [ ] Secondary failover group created in DR account
-- [ ] Initial refresh completed successfully
-- [ ] No errors in refresh history


/*******************************************************************************
 * STEP 6: MANUAL REFRESH (OPTIONAL)
 *
 * Run in: TARGET account (DR/failover account)
 * Purpose: Force an immediate refresh for validation or testing
 *
 * NOTE: If REPLICATION_SCHEDULE is set, refreshes happen automatically.
 *       Manual refresh is only needed for testing or troubleshooting.
 ******************************************************************************/

-- Optional: Increase timeout for large refreshes
-- ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 604800;

-- Manually refresh the secondary failover group
ALTER FAILOVER GROUP MY_FAILOVER_GROUP REFRESH;

-- 📋 Checklist: Manual Refresh
-- [ ] Refresh command executed successfully
-- [ ] No timeout errors
-- [ ] Refresh progress shows COMPLETED status (see Step 7)


/*******************************************************************************
 * STEP 7: MONITOR REFRESH PROGRESS
 *
 * Run in: TARGET account (DR/failover account)
 * Purpose: Track refresh operations and verify success
 * Retention: Last 14 days
 ******************************************************************************/

-- View refresh progress for the most recent refresh
SELECT
    phase_name,
    start_time,
    end_time,
    progress,
    details
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_PROGRESS('MY_FAILOVER_GROUP'))
ORDER BY start_time DESC;

-- Refresh phases to look for:
-- - PRIMARY_UPLOADING_METADATA: Source account preparing data
-- - SECONDARY_DOWNLOADING_METADATA: Target downloading metadata
-- - SECONDARY_DOWNLOADING_DATA: Target downloading actual data
-- - COMPLETED: Refresh finished successfully

-- 📋 Checklist: Progress Monitoring
-- [ ] Latest refresh shows phase_name = 'COMPLETED'
-- [ ] end_time is populated
-- [ ] No errors in details column
-- [ ] progress = 100% for all phases


/*******************************************************************************
 * STEP 8: VIEW REFRESH HISTORY
 *
 * Run in: TARGET account (DR/failover account)
 * Purpose: Review past refreshes and identify patterns
 * Retention: Last 14 days
 ******************************************************************************/

-- View refresh history (last 20 refreshes)
SELECT
    phase_name,
    start_time,
    end_time,
    total_bytes,
    object_count
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('MY_FAILOVER_GROUP'))
ORDER BY start_time DESC
LIMIT 20;

-- 📋 Checklist: History Review
-- [ ] Historical refreshes show COMPLETED status
-- [ ] No recurring failures
-- [ ] Refresh duration is acceptable for your RTO
-- [ ] Data transfer volumes are as expected


/*******************************************************************************
 * STEP 9: MONITOR USAGE AND COSTS
 *
 * Run in: TARGET account (DR/failover account)
 * Purpose: Track replication costs
 * Retention: Last 14 days
 ******************************************************************************/

-- View failover group usage (last 14 days)
SELECT
  start_time,
  end_time,
  replication_group_name,
  credits_used,
  bytes_transferred,
  bytes_transferred / 1024 / 1024 / 1024 AS gb_transferred
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_USAGE_HISTORY(
  date_range_start => DATEADD('day', -14, CURRENT_TIMESTAMP()),
  replication_group_name => 'MY_FAILOVER_GROUP'
))
ORDER BY start_time DESC;

-- Calculate total usage
SELECT
  SUM(credits_used) AS total_credits,
  SUM(bytes_transferred) / 1024 / 1024 / 1024 AS total_gb_transferred
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_USAGE_HISTORY(
  date_range_start => DATEADD('day', -14, CURRENT_TIMESTAMP()),
  replication_group_name => 'MY_FAILOVER_GROUP'
));

-- 📋 Checklist: Cost Monitoring
-- [ ] Replication costs are within budget
-- [ ] No unexpected spikes
-- [ ] Cost monitoring alerts configured


/*******************************************************************************
 * STEP 10: TEST FAILOVER (NON-PRODUCTION ENVIRONMENT)
 *
 * Run in: TARGET account (DR/failover account)
 * Purpose: Validate failover procedures BEFORE an actual disaster
 *
 * ⚠️ WARNING: ONLY TEST IN NON-PRODUCTION ENVIRONMENTS
 * Testing failover in production will make your DR account primary!
 ******************************************************************************/

-- TESTING BEST PRACTICES:
-- 1. Test failover during a scheduled maintenance window
-- 2. Notify all stakeholders before testing
-- 3. Document each step and timing
-- 4. Verify application connectivity after failover
-- 5. Practice failback procedures
-- 6. Update runbook based on test results

-- BEFORE TESTING:
-- [ ] Schedule a maintenance window
-- [ ] Notify all stakeholders
-- [ ] Document current state (primary account identifier)
-- [ ] Verify latest refresh completed successfully
-- [ ] Have rollback plan ready

-- TEST FAILOVER PROCEDURE (see Step 11 for actual failover commands)
-- This validates your runbook without impacting production


/*******************************************************************************
 * STEP 11: PERFORM ACTUAL FAILOVER (PROMOTION)
 *
 * Run in: TARGET account (the account you want to make primary)
 * Purpose: Promote the DR account to become the new primary (disaster recovery)
 *
 * ⚠️ CRITICAL: This makes the target account read-write (primary)
 * ⚠️ CRITICAL: The original primary becomes read-only (secondary)
 * ⚠️ CRITICAL: Only execute during an actual disaster or planned failover
 ******************************************************************************/

-- WHEN TO PERFORM FAILOVER:
-- - Primary region/account is unavailable
-- - Planned datacenter migration
-- - Extended primary account maintenance
-- - Disaster recovery scenario

-- FAILOVER PREREQUISITES:
-- [ ] Verify primary account is truly unavailable OR this is planned
-- [ ] Latest refresh completed successfully (if possible)
-- [ ] Stakeholders have been notified
-- [ ] Applications are ready to redirect connections

-- STEP 11A: Check for in-progress refresh operations
-- Failover will fail if a refresh is in progress
SELECT phase_name, start_time, job_uuid
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('MY_FAILOVER_GROUP'))
WHERE phase_name <> 'COMPLETED' AND phase_name <> 'CANCELED';

-- If a refresh is in progress, you have two options:
-- Option 1: Wait for it to complete (recommended)
-- Option 2: Suspend and cancel (may result in inconsistent state)
-- ALTER FAILOVER GROUP MY_FAILOVER_GROUP SUSPEND IMMEDIATE;

-- STEP 11B: Promote this account to primary (FAILOVER)
-- This is the critical command that performs the failover
ALTER FAILOVER GROUP MY_FAILOVER_GROUP PRIMARY;

-- STEP 11C: Verify the failover succeeded
SHOW FAILOVER GROUPS LIKE 'MY_FAILOVER_GROUP';
-- Check: is_primary should now be TRUE

-- STEP 11D: Resume scheduled refreshes for remaining secondary groups
-- If you have other secondary failover groups, they must be resumed
-- ALTER FAILOVER GROUP MY_FAILOVER_GROUP RESUME;

-- 📋 Checklist: Post-Failover Validation
-- [ ] Failover command completed successfully
-- [ ] is_primary = TRUE in this account
-- [ ] Databases are now read-write in this account
-- [ ] Users can authenticate
-- [ ] Warehouses are running
-- [ ] Applications can connect
-- [ ] Original primary is now read-only (if accessible)


/*******************************************************************************
 * STEP 12: UPDATE CLIENT CONNECTIONS (POST-FAILOVER)
 *
 * Run in: BOTH accounts
 * Purpose: Redirect client applications to the new primary account
 ******************************************************************************/

-- OPTION 1: Client Redirect (Recommended)
-- Snowflake can automatically redirect clients to the new primary
-- Requires FAILOVER privilege on connection objects
-- Applications continue to use the same connection string

-- Enable client redirect for a connection in both accounts:
-- (Replace connection names with your actual connection names)
-- GRANT FAILOVER ON CONNECTION my_connection TO ROLE ACCOUNTADMIN;

-- OPTION 2: Manual Connection String Update
-- Update application connection strings to point to new primary account
-- Example: Change from prod-account.snowflakecomputing.com
--          to dr-account.snowflakecomputing.com

-- 📋 Checklist: Connection Update
-- [ ] Client redirect configured (if using) OR
-- [ ] Application connection strings updated (if not using redirect)
-- [ ] Applications successfully connecting to new primary
-- [ ] User login working
-- [ ] Scheduled jobs running


/*******************************************************************************
 * STEP 13: FAILBACK PROCEDURES
 *
 * Run in: ORIGINAL primary account (after it recovers)
 * Purpose: Return to original primary account after recovery
 *
 * NOTE: Failback is essentially another failover in reverse
 ******************************************************************************/

-- WHEN TO FAIL BACK:
-- - Original primary account has been restored and validated
-- - New primary has been stable for sufficient time
-- - Planned maintenance window scheduled
-- - Business requirements to return to original architecture

-- FAILBACK STEPS:

-- STEP 13A: Verify original primary account is healthy
-- Run in ORIGINAL PRIMARY (now secondary):
SHOW FAILOVER GROUPS;
-- Verify the group exists and is_primary = FALSE

-- STEP 13B: Ensure latest data is replicated back
-- The original primary (now secondary) should be receiving refreshes
-- from the current primary (former DR account)
SELECT phase_name, start_time, end_time
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_PROGRESS('MY_FAILOVER_GROUP'))
ORDER BY start_time DESC;

-- STEP 13C: Perform failback (promote original primary)
-- Run in ORIGINAL PRIMARY account:
ALTER FAILOVER GROUP MY_FAILOVER_GROUP PRIMARY;

-- STEP 13D: Resume refreshes in the DR account
-- Run in DR account (now secondary again):
ALTER FAILOVER GROUP MY_FAILOVER_GROUP RESUME;

-- STEP 13E: Update client connections back to original primary
-- Use client redirect or update connection strings

-- 📋 Checklist: Post-Failback Validation
-- [ ] Original primary is_primary = TRUE
-- [ ] DR account is_primary = FALSE
-- [ ] Refreshes running normally
-- [ ] Applications connected to original primary
-- [ ] All functionality verified


/*******************************************************************************
 * STEP 14: CONFIGURE REPLICATION SCHEDULE
 *
 * Run in: SOURCE account (current primary)
 * Purpose: Adjust the refresh schedule to meet RPO requirements
 ******************************************************************************/

-- Change the replication schedule
ALTER FAILOVER GROUP MY_FAILOVER_GROUP SET
  REPLICATION_SCHEDULE = '10 MINUTE';

-- Examples of replication schedules:
-- '5 MINUTE'   - Every 5 minutes (RPO ~5 minutes)
-- '10 MINUTE'  - Every 10 minutes (RPO ~10 minutes)
-- '1 HOUR'     - Every hour (RPO ~1 hour)
-- 'USING CRON 0 */6 * * * UTC'  - Every 6 hours (RPO ~6 hours)

-- Suspend scheduled replication (run in TARGET account)
ALTER FAILOVER GROUP MY_FAILOVER_GROUP SUSPEND;

-- Resume scheduled replication (run in TARGET account)
ALTER FAILOVER GROUP MY_FAILOVER_GROUP RESUME;

-- 📋 Checklist: Schedule Management
-- [ ] Replication schedule matches RPO requirements
-- [ ] Secondary accounts receiving refreshes on schedule
-- [ ] Can suspend/resume as needed


/*******************************************************************************
 * STEP 15: DATA CONSISTENCY VALIDATION (OPTIONAL)
 *
 * Purpose: Verify data matches between primary and secondary
 ******************************************************************************/

-- STEP 1: Run in TARGET account to get the primary snapshot timestamp
SELECT PARSE_JSON(details)['primarySnapshotTimestamp'] AS primary_snapshot_ts
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_PROGRESS('MY_FAILOVER_GROUP'))
WHERE phase_name = 'PRIMARY_UPLOADING_METADATA';

-- STEP 2: Run in TARGET account to hash a replicated table
-- SELECT HASH_AGG(*) FROM <db>.<schema>.<table>;

-- STEP 3: Run in SOURCE account to hash at the snapshot timestamp
-- SELECT HASH_AGG(*) FROM <db>.<schema>.<table>
--   AT(TIMESTAMP => '<primarySnapshotTimestamp>'::TIMESTAMP);

-- STEP 4: Compare hash values - they should match exactly

-- 📋 Checklist: Data Validation
-- [ ] Sample tables validated
-- [ ] Hash values match
-- [ ] Row counts match
-- [ ] Critical data verified


/*******************************************************************************
 * TROUBLESHOOTING GUIDE
 ******************************************************************************/

-- Issue: "Cannot promote because refresh is in progress"
-- Solution: Wait for refresh to complete OR cancel it
ALTER FAILOVER GROUP MY_FAILOVER_GROUP SUSPEND IMMEDIATE;
-- Then verify no refreshes in progress:
SELECT phase_name FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('MY_FAILOVER_GROUP'))
WHERE phase_name <> 'COMPLETED' AND phase_name <> 'CANCELED';
-- Then retry promotion:
ALTER FAILOVER GROUP MY_FAILOVER_GROUP PRIMARY;

-- Issue: "Account not Business Critical"
-- Solution: All accounts must be Business Critical or higher for failover groups
-- Contact Snowflake Support to upgrade

-- Issue: "Database cannot be added to failover group"
-- Solution:
-- - Ensure database is not created from a share
-- - Verify you have MONITOR privilege on the database
-- - Database cannot be in another failover group

-- Issue: "Failover group refresh fails"
-- Solution: Check refresh history for details
SELECT phase_name, start_time, error_message
FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('MY_FAILOVER_GROUP'))
WHERE phase_name = 'FAILED';

-- Issue: "Client connections failing after failover"
-- Solution:
-- - Verify client redirect is configured
-- - Check connection strings point to correct account
-- - Ensure network policies allow connections
-- - Verify users and roles replicated correctly

-- Issue: "High replication costs"
-- Solution:
-- - Increase refresh interval (reduce frequency)
-- - Review ALLOWED_DATABASES list (only replicate what's needed)
-- - Use REPLICATION_GROUP_USAGE_HISTORY to analyze costs


/*******************************************************************************
 * BEST PRACTICES
 ******************************************************************************/

-- 1. PLANNING AND ARCHITECTURE
-- - Use a single failover group for complete DR (simplest)
-- - Replicate all account objects (users, roles, warehouses) for seamless failover
-- - Choose regions based on compliance and latency requirements
-- - Document your DR architecture and runbooks

-- 2. TESTING
-- - Test failover procedures quarterly in non-production
-- - Measure actual RTO during tests
-- - Verify application failover procedures
-- - Update runbooks based on test results
-- - Train team members on failover procedures

-- 3. MONITORING
-- - Monitor refresh success/failure rates
-- - Track refresh duration vs RTO requirements
-- - Set up alerts for failed refreshes
-- - Monitor replication costs
-- - Use ERROR_INTEGRATION for automatic failure notifications

-- 4. SECURITY
-- - Use least privilege: grant only necessary permissions
-- - Replicate security integrations and network policies
-- - Test user authentication after failover
-- - Verify role hierarchies after failover
-- - Document access control procedures

-- 5. OPERATIONAL EXCELLENCE
-- - Maintain current DR runbooks
-- - Keep contact lists updated
-- - Schedule regular DR drills
-- - Document lessons learned from tests
-- - Review and update RPO/RTO requirements annually

-- 6. CLIENT CONNECTIVITY
-- - Implement client redirect for seamless failover
-- - Test application reconnection logic
-- - Document connection string changes needed
-- - Have communication plan for users


/*******************************************************************************
 * FINAL CHECKLIST - BUSINESS CONTINUITY READINESS
 ******************************************************************************/

-- Configuration:
-- [ ] Primary failover group created with all necessary object types
-- [ ] Secondary failover group(s) created in DR account(s)
-- [ ] Replication schedule configured to meet RPO
-- [ ] All databases included in ALLOWED_DATABASES
-- [ ] All required integrations included

-- Validation:
-- [ ] Refreshes completing successfully on schedule
-- [ ] Refresh duration meets RTO requirements
-- [ ] Data validation performed (sample hash checks)
-- [ ] Cost monitoring in place

-- Testing:
-- [ ] Failover tested in non-production
-- [ ] Failback tested in non-production
-- [ ] Application connectivity tested after failover
-- [ ] Client redirect tested (if used)
-- [ ] RTO/RPO validated through testing

-- Documentation:
-- [ ] DR runbook created and accessible
-- [ ] Failover decision tree documented
-- [ ] Contact list (team, stakeholders, Snowflake Support)
-- [ ] Application dependencies documented
-- [ ] Communication plan for users/stakeholders

-- Operational Readiness:
-- [ ] Team trained on failover procedures
-- [ ] Alerts configured for refresh failures
-- [ ] Regular DR drills scheduled
-- [ ] Escalation procedures documented
-- [ ] Post-failover validation checklist created


/*******************************************************************************
 * ADDITIONAL RESOURCES
 ******************************************************************************/

-- Snowflake Documentation:
-- - https://docs.snowflake.com/en/user-guide/account-replication-intro
-- - https://docs.snowflake.com/en/user-guide/account-replication-failover-failback
-- - https://docs.snowflake.com/en/user-guide/database-failover-config

-- Key SQL Commands (Failover Groups):
-- - SHOW REPLICATION ACCOUNTS
-- - CREATE FAILOVER GROUP
-- - ALTER FAILOVER GROUP ... REFRESH
-- - ALTER FAILOVER GROUP ... PRIMARY (failover)
-- - ALTER FAILOVER GROUP ... SUSPEND / RESUME
-- - DROP FAILOVER GROUP
-- - SHOW FAILOVER GROUPS
-- - SHOW DATABASES IN FAILOVER GROUP

-- Monitoring (Information Schema Table Functions):
-- - INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_PROGRESS('<group_name>')
-- - INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('<group_name>')
-- - INFORMATION_SCHEMA.REPLICATION_GROUP_USAGE_HISTORY(...)

-- For basic redundancy (read-only replicas), see:
-- - enterprise_replication_guide.sql


/*******************************************************************************
 * CLEANUP (OPTIONAL - USE WITH EXTREME CAUTION)
 *
 * ⚠️ WARNING: Dropping failover groups changes your DR capability
 * ⚠️ WARNING: Dropping a secondary can make replicated databases writable
 ******************************************************************************/

-- CLEANUP ORDER:
-- 1. Drop secondary failover groups first (in all DR accounts)
-- 2. Then drop primary failover group (in source account)

-- Run in each TARGET account:
-- DROP FAILOVER GROUP IF EXISTS MY_FAILOVER_GROUP;

-- Run in SOURCE account (only after all secondaries are dropped):
-- DROP FAILOVER GROUP IF EXISTS MY_FAILOVER_GROUP;


/*******************************************************************************
 * END OF GUIDE
 ******************************************************************************/
