-- ============================================================================
-- ACCOUNT SETUP PREREQUISITE GUIDE FOR REPLICATION
-- ============================================================================
--
-- PURPOSE:
--   This guide walks you through the prerequisites for setting up replication
--   or failover in Snowflake. Complete these steps BEFORE using either:
--   - enterprise_replication_guide.sql (Standard/Enterprise editions)
--   - business_critical_failover_guide.sql (Business Critical edition)
--
-- WHAT YOU'LL ACCOMPLISH:
--   1. Verify you have the correct administrative role (ORGADMIN)
--   2. Review existing accounts in your organization
--   3. Create a new target account (if needed)
--   4. Enable replication for source and target accounts
--   5. Verify accounts are ready for replication setup
--
-- TIME ESTIMATE: 10-15 minutes
--
-- IMPORTANT NOTES:
--   - You must have ORGADMIN privileges in an ORGADMIN-enabled account
--   - OR use GLOBALORGADMIN role in an organization account (preferred)
--   - Account creation takes ~30 seconds for DNS propagation
--   - Replication must be enabled on BOTH source and target accounts
--
-- ============================================================================

-- ============================================================================
-- STEP 1: VERIFY ADMINISTRATIVE ROLE
-- ============================================================================
--
-- To perform these tasks, you need organization-level administrative privileges.
-- There are two approaches depending on your organization setup:
--
-- APPROACH A (Preferred - Organization Account):
--   If your organization has an "organization account", use the
--   GLOBALORGADMIN role in that account.
--
-- APPROACH B (Legacy - ORGADMIN-enabled Account):
--   If you don't have an organization account, use the ORGADMIN role
--   in an ORGADMIN-enabled account.
--
-- Check which approach applies to your organization by running:

SHOW ACCOUNTS;

-- WHAT TO LOOK FOR:
--   - If you see an account with "IS_ORG_ADMIN" = TRUE, you can use APPROACH A or B
--   - If you're already in an organization account, use GLOBALORGADMIN
--   - If unsure, try APPROACH A first, then fall back to APPROACH B

-- ============================================================================
-- APPROACH A: Using GLOBALORGADMIN in Organization Account
-- ============================================================================

USE ROLE GLOBALORGADMIN;

-- If the above fails, proceed to APPROACH B

-- ============================================================================
-- APPROACH B: Using ORGADMIN in an ORGADMIN-enabled Account
-- ============================================================================

USE ROLE ORGADMIN;

-- If both fail, you need to:
--   1. Contact your Snowflake administrator to grant you ORGADMIN privileges
--   2. OR create an organization account (requires existing ORGADMIN access)

-- ============================================================================
-- STEP 2: UNDERSTAND SNOWFLAKE ACCOUNT IDENTIFIERS
-- ============================================================================
--
-- Account identifiers in Snowflake follow this format:
--   <organization_name>.<account_name>
--
-- EXAMPLE BREAKDOWN:
--   ACME_CORP.PROD_US_EAST     →  Organization: ACME_CORP, Account: PROD_US_EAST
--   ACME_CORP.DR_US_WEST       →  Organization: ACME_CORP, Account: DR_US_WEST
--   GLOBEX.EUROPE_ANALYTICS    →  Organization: GLOBEX, Account: EUROPE_ANALYTICS
--
-- WHY THIS MATTERS:
--   - You'll use these identifiers to enable replication
--   - Both source and target accounts must be in the SAME organization
--   - The format must be exact when running system functions
--
-- YOUR ORGANIZATION NAME:
--   Run SHOW ACCOUNTS and note the ORGANIZATION_NAME column
--   All accounts in your organization will share this name

-- ============================================================================
-- STEP 3: REVIEW EXISTING ACCOUNTS IN YOUR ORGANIZATION
-- ============================================================================

-- View all accounts in your organization
SHOW ACCOUNTS;

-- EXAMINE THE OUTPUT:
-- +------------------+------------+--------------+-----------------+---------+-------------------+--------------+
-- | SNOWFLAKE_REGION | CREATED_ON | ACCOUNT_NAME | ACCOUNT_LOCATOR | COMMENT | ORGANIZATION_NAME | IS_ORG_ADMIN |
-- +------------------+------------+--------------+-----------------+---------+-------------------+--------------+
-- | AWS_US_WEST_2    | ...        | PROD_ACCOUNT | xy12345         |         | ACME_CORP         | TRUE         |
-- | AWS_US_EAST_1    | ...        | DR_ACCOUNT   | zw98765         |         | ACME_CORP         | FALSE        |
-- +------------------+------------+--------------+-----------------+---------+-------------------+--------------+
--
-- KEY INFORMATION TO NOTE:
--   - ORGANIZATION_NAME: Your organization identifier (e.g., ACME_CORP)
--   - ACCOUNT_NAME: Short name for each account (e.g., PROD_ACCOUNT, DR_ACCOUNT)
--   - SNOWFLAKE_REGION: Where the account is located (e.g., AWS_US_WEST_2)
--   - EDITION: Account edition (shown in detailed view)
--
-- RECORD YOUR ACCOUNTS:
--   Source Account (where data currently lives):
--     Organization Name: _________________________
--     Account Name: _____________________________
--     Full Identifier: _________________________  (format: ORG_NAME.ACCOUNT_NAME)
--
--   Target Account (where you want to replicate):
--     IF IT EXISTS - note the name: _______________
--     IF IT DOESN'T EXIST - you'll create it in Step 4

-- ============================================================================
-- STEP 4: CREATE A NEW TARGET ACCOUNT (OPTIONAL)
-- ============================================================================
--
-- Only complete this step if you need to create a NEW account for replication.
-- If your target account already exists, skip to STEP 5.
--
-- IMPORTANT DECISIONS BEFORE CREATING:
--
-- 1. CHOOSE AN EDITION:
--    - STANDARD: Basic replication (read-only replicas)
--    - ENTERPRISE: Enhanced replication features
--    - BUSINESS_CRITICAL: Full failover/failback capabilities (recommended for DR)
--
-- 2. CHOOSE A REGION:
--    - Same region as source: Lower latency, lower cost
--    - Different region: Geographic redundancy, disaster recovery
--    - View available regions: SHOW REGIONS;
--
-- 3. NAMING CONVENTION:
--    - Use descriptive names that indicate purpose and location
--    - Examples: DR_US_WEST, REPLICA_EUROPE, BACKUP_EAST
--    - Names must start with a letter and can contain letters, numbers, underscores
--    - No spaces or special characters (except underscores)

-- First, view available regions:
SHOW REGIONS;

-- CREATE ACCOUNT TEMPLATE:
-- Uncomment and customize the command below to create your new account

/*
CREATE ACCOUNT YOUR_NEW_ACCOUNT_NAME
  ADMIN_NAME = 'admin'
  ADMIN_PASSWORD = 'ChangeMe123!@#' -- pragma: allowlist secret
  FIRST_NAME = 'Admin'
  LAST_NAME = 'User'
  EMAIL = 'admin@yourcompany.com'
  MUST_CHANGE_PASSWORD = TRUE
  EDITION = BUSINESS_CRITICAL           -- or ENTERPRISE or STANDARD
  REGION = aws_us_west_2;               -- Choose appropriate region
*/

-- REAL EXAMPLE:
-- Creating a disaster recovery account in US West for an organization named ACME_CORP:
/*
CREATE ACCOUNT DR_US_WEST
  ADMIN_NAME = 'dr_admin'
  ADMIN_PASSWORD = 'SecurePassword123!@#' -- pragma: allowlist secret
  FIRST_NAME = 'DR'
  LAST_NAME = 'Administrator'
  EMAIL = 'dr-admin@acme.com'
  MUST_CHANGE_PASSWORD = TRUE
  EDITION = BUSINESS_CRITICAL
  REGION = aws_us_west_2
  COMMENT = 'Disaster recovery account for PROD_US_EAST';
*/

-- AFTER CREATING THE ACCOUNT:
--   1. Wait ~30 seconds for DNS propagation
--   2. Run SHOW ACCOUNTS again to verify the account was created
--   3. Note the full account identifier (ORGANIZATION_NAME.ACCOUNT_NAME)
--   4. You can log into the new account using: https://<organization_name>-<account_name>.snowflakecomputing.com

-- Verify the new account was created:
SHOW ACCOUNTS;

-- ============================================================================
-- STEP 5: ENABLE REPLICATION FOR SOURCE AND TARGET ACCOUNTS
-- ============================================================================
--
-- CRITICAL: Replication must be enabled on BOTH the source account AND all
-- target accounts before you can create replication or failover groups.
--
-- The SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER function enables replication
-- for a specific account in your organization.

-- First, view accounts that already have replication enabled:
SHOW REPLICATION ACCOUNTS;

-- EXPECTED OUTPUT (if accounts are already enabled):
-- +------------------+------------+--------------+-----------------+---------+-------------------+--------------+
-- | SNOWFLAKE_REGION | CREATED_ON | ACCOUNT_NAME | ACCOUNT_LOCATOR | COMMENT | ORGANIZATION_NAME | IS_ORG_ADMIN |
-- +------------------+------------+--------------+-----------------+---------+-------------------+--------------+
-- | AWS_US_WEST_2    | ...        | PROD_ACCOUNT | xy12345         |         | ACME_CORP         | TRUE         |
-- | AWS_US_EAST_1    | ...        | DR_ACCOUNT   | zw98765         |         | ACME_CORP         | FALSE        |
-- +------------------+------------+--------------+-----------------+---------+-------------------+--------------+
--
-- If your source or target accounts are NOT listed, you need to enable them.

-- ============================================================================
-- ENABLE REPLICATION: SOURCE ACCOUNT
-- ============================================================================

-- Replace placeholders with YOUR actual organization and account names:
SELECT SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER(
  'YOUR_ORG_NAME.YOUR_SOURCE_ACCOUNT',      -- Format: ORGANIZATION.ACCOUNT
  'ENABLE_ACCOUNT_DATABASE_REPLICATION',
  'true'
);

-- REAL EXAMPLE:
-- Enabling replication for a source account named PROD_US_EAST in organization ACME_CORP:
/*
SELECT SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER(
  'ACME_CORP.PROD_US_EAST',
  'ENABLE_ACCOUNT_DATABASE_REPLICATION',
  'true'
);
*/

-- Expected result: Returns a success message or JSON status

-- ============================================================================
-- ENABLE REPLICATION: TARGET ACCOUNT
-- ============================================================================

-- Replace placeholders with YOUR actual organization and account names:
SELECT SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER(
  'YOUR_ORG_NAME.YOUR_TARGET_ACCOUNT',      -- Format: ORGANIZATION.ACCOUNT
  'ENABLE_ACCOUNT_DATABASE_REPLICATION',
  'true'
);

-- REAL EXAMPLE:
-- Enabling replication for a target account named DR_US_WEST in organization ACME_CORP:
/*
SELECT SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER(
  'ACME_CORP.DR_US_WEST',
  'ENABLE_ACCOUNT_DATABASE_REPLICATION',
  'true'
);
*/

-- Expected result: Returns a success message or JSON status

-- ============================================================================
-- ENABLE REPLICATION: ADDITIONAL TARGET ACCOUNTS (IF NEEDED)
-- ============================================================================
--
-- If you're replicating to multiple target accounts, repeat the command above
-- for each additional target account.
--
-- Example: Enabling a second target in Europe:
/*
SELECT SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER(
  'ACME_CORP.DR_EUROPE',
  'ENABLE_ACCOUNT_DATABASE_REPLICATION',
  'true'
);
*/

-- ============================================================================
-- STEP 6: VERIFY REPLICATION IS ENABLED
-- ============================================================================

-- View all accounts that are now enabled for replication:
SHOW REPLICATION ACCOUNTS;

-- VERIFY THE OUTPUT:
--   ✓ Your source account should be listed
--   ✓ All your target accounts should be listed
--   ✓ Note the full identifiers for use in the next guide
--
-- If any accounts are MISSING from this list:
--   1. Double-check the account identifier format (ORGANIZATION.ACCOUNT)
--   2. Ensure you used the exact names from SHOW ACCOUNTS
--   3. Re-run the SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER command for missing accounts
--   4. Wait a few seconds and run SHOW REPLICATION ACCOUNTS again

-- ============================================================================
-- STEP 7: RECORD YOUR CONFIGURATION
-- ============================================================================
--
-- Before proceeding to the replication or failover guide, document your setup:
--
-- ORGANIZATION NAME: _______________________
--
-- SOURCE ACCOUNT:
--   Account Name: ___________________________
--   Full Identifier: ________________________ (e.g., ACME_CORP.PROD_US_EAST)
--   Region: _________________________________
--   Edition: ________________________________
--
-- TARGET ACCOUNT(S):
--   Account Name: ___________________________
--   Full Identifier: ________________________ (e.g., ACME_CORP.DR_US_WEST)
--   Region: _________________________________
--   Edition: ________________________________
--
--   [Additional targets if applicable]
--   Account Name: ___________________________
--   Full Identifier: ________________________
--   Region: _________________________________
--   Edition: ________________________________

-- ============================================================================
-- NEXT STEPS
-- ============================================================================
--
-- Congratulations! Your accounts are now ready for replication setup.
--
-- CHOOSE YOUR NEXT GUIDE BASED ON YOUR EDITION:
--
-- FOR STANDARD/ENTERPRISE EDITIONS:
--   → Use: enterprise_replication_guide.sql
--   → Purpose: Set up replication groups for read-only replicas
--   → Use case: Basic redundancy, read scaling, data distribution
--
-- FOR BUSINESS CRITICAL EDITION:
--   → Use: business_critical_failover_guide.sql
--   → Purpose: Set up failover groups with full DR capabilities
--   → Use case: Disaster recovery, high availability, automatic failover
--
-- IMPORTANT REMINDERS:
--   ✓ Keep your recorded configuration handy for the next guide
--   ✓ Ensure you can log into BOTH source and target accounts
--   ✓ For failover groups, you'll need appropriate roles in both accounts
--   ✓ Budget for replication costs (data transfer and storage)

-- ============================================================================
-- TROUBLESHOOTING
-- ============================================================================
--
-- PROBLEM: "Insufficient privileges to execute SHOW ACCOUNTS"
-- SOLUTION: Ensure you're using ORGADMIN or GLOBALORGADMIN role
--
-- PROBLEM: "Account identifier not found"
-- SOLUTION: Run SHOW ACCOUNTS and verify exact spelling of organization
--           and account names (they are case-sensitive in the function)
--
-- PROBLEM: "Cannot create account - limit exceeded"
-- SOLUTION: Contact Snowflake Support to increase your organization's
--           account limit (default is 25 accounts)
--
-- PROBLEM: "New account not accessible"
-- SOLUTION: Wait 30-60 seconds for DNS propagation, then try again
--
-- PROBLEM: "SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER failed"
-- SOLUTION: Verify:
--           1. You're using the correct role (ORGADMIN/GLOBALORGADMIN)
--           2. Account identifier format is correct (ORG.ACCOUNT)
--           3. Account exists (run SHOW ACCOUNTS to verify)
--
-- For additional help, contact Snowflake Support or consult:
-- https://docs.snowflake.com/en/user-guide/account-replication-intro

-- ============================================================================
-- COST CONSIDERATIONS
-- ============================================================================
--
-- ACCOUNT CREATION:
--   - Free to create additional accounts in your organization
--   - Each account is billed separately for compute and storage usage
--
-- REPLICATION ENABLEMENT:
--   - No cost to enable replication on an account
--
-- ACTUAL REPLICATION COSTS (incurred when using the next guide):
--   - Data transfer costs for cross-region replication
--   - Storage costs in target accounts
--   - Compute costs for refresh operations
--
-- RECOMMENDATION:
--   - Start with the same region for source and target (lower costs)
--   - Test with small databases first
--   - Review Snowflake pricing documentation for your specific regions

-- ============================================================================
-- END OF ACCOUNT SETUP PREREQUISITE GUIDE
-- ============================================================================
