/*==============================================================================
GUARDRAILS -- MSP Provider Guide
Network rules, authentication policies, masking policies, and audit checks.
Run as MSP_ACCOUNT_ADMIN / ACCOUNTADMIN in each customer account.
==============================================================================*/

----------------------------------------------------------------------
-- 1. Network rules (modern pattern — replaces ALLOWED_IP_LIST)
----------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- MSP office/VPN
CREATE NETWORK RULE IF NOT EXISTS MSP_INGRESS_RULE
    MODE       = INGRESS
    TYPE       = IPV4
    VALUE_LIST = ('198.51.100.0/24')
    COMMENT    = 'MSP corporate IP range';

-- Customer office/VPN
CREATE NETWORK RULE IF NOT EXISTS CUST_INGRESS_RULE
    MODE       = INGRESS
    TYPE       = IPV4
    VALUE_LIST = ('192.0.2.0/24')
    COMMENT    = 'Customer corporate IP range';

-- Account-level network policy (applies to all users by default)
CREATE NETWORK POLICY IF NOT EXISTS ACCOUNT_NETWORK_POLICY
    ALLOWED_NETWORK_RULE_LIST = (MSP_INGRESS_RULE, CUST_INGRESS_RULE)
    COMMENT = 'Account-wide policy: MSP + customer IPs only';

ALTER ACCOUNT SET NETWORK_POLICY = ACCOUNT_NETWORK_POLICY;

-- Vendor-specific policies are created per vendor in 02_vendor_onboard.sql
-- and applied at the user level, which takes precedence over the account policy.

----------------------------------------------------------------------
-- 2. Authentication policies
----------------------------------------------------------------------

-- Account-wide: require MFA for all password-based logins
CREATE AUTHENTICATION POLICY IF NOT EXISTS ACCOUNT_AUTH_POLICY
    MFA_ENROLLMENT        = 'REQUIRED'
    CLIENT_TYPES          = ('SNOWFLAKE_UI', 'SNOWSQL', 'DRIVERS')
    COMMENT               = 'Account-wide MFA enforcement';

ALTER ACCOUNT SET AUTHENTICATION POLICY ACCOUNT_AUTH_POLICY;

----------------------------------------------------------------------
-- 3. Masking policies
----------------------------------------------------------------------

-- Example: mask email addresses for non-MSP roles
-- IS_ROLE_IN_SESSION respects role hierarchy; CURRENT_ROLE() does not.
CREATE MASKING POLICY IF NOT EXISTS PRESENTATION.ANALYTICS.EMAIL_MASK AS
    (val STRING) RETURNS STRING ->
    CASE
        WHEN IS_ROLE_IN_SESSION('MSP_ACCOUNT_ADMIN')
          OR IS_ROLE_IN_SESSION('MSP_SECURITY_ADMIN')
          OR IS_ROLE_IN_SESSION('MSP_PLATFORM_ENGINEER')
        THEN val
        ELSE REGEXP_REPLACE(val, '.+@', '***@')
    END
    COMMENT = 'Mask email prefix for non-MSP roles';

-- Example: mask SSN to last 4 digits
CREATE MASKING POLICY IF NOT EXISTS PRESENTATION.ANALYTICS.SSN_MASK AS
    (val STRING) RETURNS STRING ->
    CASE
        WHEN IS_ROLE_IN_SESSION('MSP_ACCOUNT_ADMIN')
          OR IS_ROLE_IN_SESSION('MSP_SECURITY_ADMIN')
          OR IS_ROLE_IN_SESSION('MSP_PLATFORM_ENGINEER')
        THEN val
        ELSE '***-**-' || RIGHT(val, 4)
    END
    COMMENT = 'Mask SSN to last 4 digits for non-MSP roles';

-- Apply to a column:
-- ALTER TABLE PRESENTATION.ANALYTICS.CUSTOMERS
--     MODIFY COLUMN email SET MASKING POLICY PRESENTATION.ANALYTICS.EMAIL_MASK;

----------------------------------------------------------------------
-- 4. Row access policies
----------------------------------------------------------------------

-- Example: restrict vendor READONLY roles to see only their own data
-- Uses IS_ROLE_IN_SESSION for hierarchy-aware checks and
-- CURRENT_ROLE() only for the vendor name extraction (exact match intended).
CREATE ROW ACCESS POLICY IF NOT EXISTS PRESENTATION.API.VENDOR_ROW_FILTER AS
    (vendor_col STRING) RETURNS BOOLEAN ->
    CASE
        WHEN IS_ROLE_IN_SESSION('MSP_ACCOUNT_ADMIN')
          OR IS_ROLE_IN_SESSION('MSP_PLATFORM_ENGINEER')
          OR IS_ROLE_IN_SESSION('CUST_ADMIN')
          OR IS_ROLE_IN_SESSION('CUST_ANALYST')
        THEN TRUE
        WHEN CURRENT_ROLE() LIKE 'VENDOR_%_READONLY'
        THEN vendor_col = REPLACE(CURRENT_ROLE(), '_READONLY', '')
        ELSE FALSE
    END
    COMMENT = 'Vendor READONLY roles see only their own data';

-- Apply to a view:
-- ALTER VIEW PRESENTATION.API.VENDOR_SUMMARY
--     ADD ROW ACCESS POLICY PRESENTATION.API.VENDOR_ROW_FILTER ON (vendor_name);

----------------------------------------------------------------------
-- 5. Audit checks — run periodically
----------------------------------------------------------------------

-- 5a. Vendor roles that somehow got account-level privileges
SELECT grantee_name, privilege
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE grantee_name LIKE 'VENDOR_%'
  AND privilege IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN',
                    'CREATE SHARE', 'IMPORT SHARE', 'MANAGE GRANTS',
                    'CREATE DATABASE', 'CREATE WAREHOUSE')
  AND deleted_on IS NULL;

-- 5b. Vendor roles that own objects outside their RAW_VENDOR schema
SELECT grantee_name, granted_on, name, table_catalog, table_schema
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE grantee_name LIKE 'VENDOR_%'
  AND privilege = 'OWNERSHIP'
  AND table_catalog != 'RAW_VENDOR'
  AND deleted_on IS NULL;

-- 5c. Users without MFA enrolled
SELECT name, has_mfa, default_role
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE deleted_on IS NULL
  AND has_mfa = FALSE;

-- 5d. Network policies — list all entities the account network policy is assigned to
SELECT policy_name, ref_entity_name, ref_entity_domain
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
    POLICY_NAME => 'ACCOUNT_NETWORK_POLICY',
    POLICY_KIND => 'NETWORK_POLICY'
));
