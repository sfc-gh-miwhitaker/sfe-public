/*==============================================================================
VENDOR OFFBOARDING -- MSP Provider Guide
Run as MSP_ACCOUNT_ADMIN (or ACCOUNTADMIN) in the customer account.
Set vendor_name, then execute top to bottom.
==============================================================================*/

----------------------------------------------------------------------
-- 0. Parameters
----------------------------------------------------------------------
SET vendor_name = 'VENDOR_X';

----------------------------------------------------------------------
-- 1. Disable vendor users immediately
--    Query for all users whose default role is the vendor ingest role.
----------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- Find all users assigned to vendor roles
-- Review this list before proceeding.
SELECT name, default_role, last_success_login, disabled
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE default_role IN ($vendor_name || '_INGEST', $vendor_name || '_READONLY')
  AND deleted_on IS NULL;

-- Disable each vendor user (replace with actual usernames from the query above)
-- ALTER USER <vendor_user> SET DISABLED = TRUE;

----------------------------------------------------------------------
-- 2. Revoke role grants from users
----------------------------------------------------------------------
-- For each vendor user found above:
-- REVOKE ROLE IDENTIFIER($vendor_name || '_INGEST')   FROM USER <vendor_user>;
-- REVOKE ROLE IDENTIFIER($vendor_name || '_READONLY')  FROM USER <vendor_user>;

----------------------------------------------------------------------
-- 3. Suspend the vendor warehouse
----------------------------------------------------------------------
ALTER WAREHOUSE IF EXISTS IDENTIFIER($vendor_name || '_INGEST_WH') SUSPEND;

----------------------------------------------------------------------
-- 4. Transfer ownership of vendor objects to MSP
--    This lets MSP_PLATFORM_ENGINEER manage or archive them.
----------------------------------------------------------------------
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name)
    COPY CURRENT GRANTS TO ROLE MSP_PLATFORM_ENGINEER REVOKE CURRENT GRANTS;
GRANT OWNERSHIP ON ALL STAGES IN SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name)
    COPY CURRENT GRANTS TO ROLE MSP_PLATFORM_ENGINEER REVOKE CURRENT GRANTS;
GRANT OWNERSHIP ON ALL FILE FORMATS IN SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name)
    COPY CURRENT GRANTS TO ROLE MSP_PLATFORM_ENGINEER REVOKE CURRENT GRANTS;
GRANT OWNERSHIP ON ALL PIPES IN SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name)
    COPY CURRENT GRANTS TO ROLE MSP_PLATFORM_ENGINEER REVOKE CURRENT GRANTS;
GRANT OWNERSHIP ON ALL TASKS IN SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name)
    COPY CURRENT GRANTS TO ROLE MSP_PLATFORM_ENGINEER REVOKE CURRENT GRANTS;

----------------------------------------------------------------------
-- 5. Revoke all grants from vendor roles
----------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name)
    FROM ROLE IDENTIFIER($vendor_name || '_INGEST');
REVOKE USAGE ON DATABASE RAW_VENDOR
    FROM ROLE IDENTIFIER($vendor_name || '_INGEST');
REVOKE USAGE ON WAREHOUSE IDENTIFIER($vendor_name || '_INGEST_WH')
    FROM ROLE IDENTIFIER($vendor_name || '_INGEST');

REVOKE ALL PRIVILEGES ON SCHEMA PRESENTATION.API
    FROM ROLE IDENTIFIER($vendor_name || '_READONLY');
REVOKE USAGE ON DATABASE PRESENTATION
    FROM ROLE IDENTIFIER($vendor_name || '_READONLY');

----------------------------------------------------------------------
-- 6. (Optional) Drop vendor objects if data is no longer needed
--    CAUTION: verify that MSP pipelines have migrated or archived data.
----------------------------------------------------------------------
-- DROP SCHEMA IF EXISTS IDENTIFIER('RAW_VENDOR.' || $vendor_name) CASCADE;
-- DROP WAREHOUSE IF EXISTS IDENTIFIER($vendor_name || '_INGEST_WH');

----------------------------------------------------------------------
-- 7. Unset policies from vendor users, then drop users
--    Policies cannot be dropped while still assigned to a user.
----------------------------------------------------------------------
-- For each vendor user found in step 1:
-- ALTER USER <vendor_user> UNSET NETWORK_POLICY;
-- ALTER USER <vendor_user> UNSET AUTHENTICATION POLICY;
-- DROP USER IF EXISTS <vendor_user>;

----------------------------------------------------------------------
-- 8. Drop network and auth policies (now unassigned)
----------------------------------------------------------------------
DROP NETWORK POLICY IF EXISTS IDENTIFIER($vendor_name || '_NETWORK_POLICY');
DROP NETWORK RULE IF EXISTS IDENTIFIER('RAW_VENDOR.' || $vendor_name || '.VENDOR_INGRESS_RULE');
DROP AUTHENTICATION POLICY IF EXISTS IDENTIFIER('RAW_VENDOR.' || $vendor_name || '.VENDOR_AUTH_POLICY');

----------------------------------------------------------------------
-- 9. Drop vendor roles
----------------------------------------------------------------------
DROP ROLE IF EXISTS IDENTIFIER($vendor_name || '_INGEST');
DROP ROLE IF EXISTS IDENTIFIER($vendor_name || '_READONLY');

----------------------------------------------------------------------
-- 10. Drop resource monitor
----------------------------------------------------------------------
DROP RESOURCE MONITOR IF EXISTS IDENTIFIER($vendor_name || '_MONITOR');

----------------------------------------------------------------------
-- 11. Verification — confirm nothing remains
----------------------------------------------------------------------
SHOW ROLES LIKE '%' || $vendor_name || '%';
SHOW USERS LIKE '%' || $vendor_name || '%';
SHOW SCHEMAS IN DATABASE RAW_VENDOR;
