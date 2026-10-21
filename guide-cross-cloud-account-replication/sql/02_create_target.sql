/*
 * Cross-cloud account replication: create the Azure target account
 * Pair-programmed by SE Community + Cortex Code
 *
 * Run as the organization administrator: GLOBALORGADMIN in the organization account,
 * or ORGADMIN in an ORGADMIN-enabled account. Skip CREATE ACCOUNT if the Azure account
 * already exists; still run the two enable-replication calls.
 *
 * Replace the source account name and the temporary password before running.
 * (The password is a credential; it must not be stored in this file.)
 */

USE ROLE ORGADMIN;   -- or GLOBALORGADMIN in the organization account

-- Target region: pick one from SHOW REGIONS LIKE 'AZURE%' in 01_preflight.sql.
-- Must be BUSINESS_CRITICAL to receive users, roles, warehouses, and integrations
-- and to fail over.
CREATE ACCOUNT IF NOT EXISTS AZURE_DR
  ADMIN_NAME           = DR_ADMIN
  ADMIN_PASSWORD       = '<temporary-password>'  -- pragma: allowlist secret
  ADMIN_USER_TYPE      = PERSON
  MUST_CHANGE_PASSWORD = TRUE
  EMAIL                = '<admin-email>'
  EDITION              = BUSINESS_CRITICAL
  REGION               = AZURE_EASTUS2
  COMMENT              = 'Replica of AWS source account';

-- Enable replication on BOTH accounts. Use organization.account names, not locators:
-- locators can collide across regions and give unexpected results.
SELECT SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER(
         CURRENT_ORGANIZATION_NAME() || '.' || '<SOURCE_ACCOUNT_NAME>',
         'ENABLE_ACCOUNT_DATABASE_REPLICATION', 'true');

SELECT SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER(
         CURRENT_ORGANIZATION_NAME() || '.' || 'AZURE_DR',
         'ENABLE_ACCOUNT_DATABASE_REPLICATION', 'true');

-- Both accounts should now appear.
SHOW REPLICATION ACCOUNTS;
