/*==============================================================================
VENDOR ONBOARDING -- MSP Provider Guide
Run as MSP_ACCOUNT_ADMIN (or ACCOUNTADMIN) in the customer account.
Set the vendor_name variable, then execute top to bottom.
==============================================================================*/

----------------------------------------------------------------------
-- 0. Parameters — change these per vendor
----------------------------------------------------------------------
SET vendor_name     = 'VENDOR_X';       -- uppercase, no spaces
SET vendor_wh_size  = 'XSMALL';         -- warehouse size for this vendor
SET vendor_ip_range = '203.0.113.0/24'; -- vendor office/VPN CIDR

----------------------------------------------------------------------
-- 1. Roles
----------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS IDENTIFIER($vendor_name || '_INGEST')
    COMMENT = 'Vendor ' || $vendor_name || ' — ingest and stage management';
CREATE ROLE IF NOT EXISTS IDENTIFIER($vendor_name || '_READONLY')
    COMMENT = 'Vendor ' || $vendor_name || ' — optional read-only on curated views';

-- Wire into MSP hierarchy so MSP_PLATFORM_ENGINEER inherits access
GRANT ROLE IDENTIFIER($vendor_name || '_INGEST')   TO ROLE MSP_PLATFORM_ENGINEER;
GRANT ROLE IDENTIFIER($vendor_name || '_READONLY')  TO ROLE MSP_PLATFORM_ENGINEER;

----------------------------------------------------------------------
-- 2. Schema (MANAGED ACCESS — only schema owner or MANAGE GRANTS role can grant)
----------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS IDENTIFIER('RAW_VENDOR.' || $vendor_name)
    WITH MANAGED ACCESS
    COMMENT = 'Raw landing zone for vendor ' || $vendor_name;

----------------------------------------------------------------------
-- 3. Warehouse
----------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($vendor_name || '_INGEST_WH')
    WAREHOUSE_SIZE      = $vendor_wh_size
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT             = 'Ingest warehouse for vendor ' || $vendor_name;

-- Tag for cost attribution
ALTER WAREHOUSE IDENTIFIER($vendor_name || '_INGEST_WH')
    SET TAG RAW_INTERNAL.PUBLIC.COST_CENTER = 'vendor';

-- Resource monitor for the vendor warehouse
CREATE RESOURCE MONITOR IF NOT EXISTS IDENTIFIER($vendor_name || '_MONITOR')
    WITH CREDIT_QUOTA = 50
    FREQUENCY         = MONTHLY
    START_TIMESTAMP   = IMMEDIATELY
    TRIGGERS
        ON 80 PERCENT DO NOTIFY
        ON 95 PERCENT DO SUSPEND;

ALTER WAREHOUSE IDENTIFIER($vendor_name || '_INGEST_WH')
    SET RESOURCE_MONITOR = IDENTIFIER($vendor_name || '_MONITOR');

----------------------------------------------------------------------
-- 4. Grants — INGEST role
----------------------------------------------------------------------
-- Database + schema access
GRANT USAGE ON DATABASE RAW_VENDOR TO ROLE IDENTIFIER($vendor_name || '_INGEST');
GRANT USAGE ON SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name)
    TO ROLE IDENTIFIER($vendor_name || '_INGEST');

-- Object creation privileges in their schema
GRANT CREATE TABLE      ON SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name) TO ROLE IDENTIFIER($vendor_name || '_INGEST');
GRANT CREATE STAGE      ON SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name) TO ROLE IDENTIFIER($vendor_name || '_INGEST');
GRANT CREATE FILE FORMAT ON SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name) TO ROLE IDENTIFIER($vendor_name || '_INGEST');
GRANT CREATE PIPE       ON SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name) TO ROLE IDENTIFIER($vendor_name || '_INGEST');
GRANT CREATE TASK       ON SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name) TO ROLE IDENTIFIER($vendor_name || '_INGEST');

-- Warehouse
GRANT USAGE ON WAREHOUSE IDENTIFIER($vendor_name || '_INGEST_WH')
    TO ROLE IDENTIFIER($vendor_name || '_INGEST');

-- Future grants so MSP pipelines can read whatever the vendor creates
GRANT SELECT ON FUTURE TABLES IN SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name)
    TO ROLE MSP_PLATFORM_ENGINEER;
GRANT USAGE  ON FUTURE STAGES IN SCHEMA IDENTIFIER('RAW_VENDOR.' || $vendor_name)
    TO ROLE MSP_PLATFORM_ENGINEER;

----------------------------------------------------------------------
-- 5. Grants — READONLY role (optional)
----------------------------------------------------------------------
GRANT USAGE  ON DATABASE PRESENTATION TO ROLE IDENTIFIER($vendor_name || '_READONLY');
GRANT USAGE  ON SCHEMA PRESENTATION.API TO ROLE IDENTIFIER($vendor_name || '_READONLY');
GRANT SELECT ON ALL VIEWS IN SCHEMA PRESENTATION.API TO ROLE IDENTIFIER($vendor_name || '_READONLY');
GRANT SELECT ON FUTURE VIEWS IN SCHEMA PRESENTATION.API TO ROLE IDENTIFIER($vendor_name || '_READONLY');
GRANT USAGE  ON WAREHOUSE IDENTIFIER($vendor_name || '_INGEST_WH')
    TO ROLE IDENTIFIER($vendor_name || '_READONLY');

----------------------------------------------------------------------
-- 6. Network rule + policy for this vendor
----------------------------------------------------------------------
CREATE NETWORK RULE IF NOT EXISTS IDENTIFIER('RAW_VENDOR.' || $vendor_name || '.VENDOR_INGRESS_RULE')
    MODE       = INGRESS
    TYPE       = IPV4
    VALUE_LIST = ($vendor_ip_range)
    COMMENT    = 'Allowed IP range for vendor ' || $vendor_name;

CREATE NETWORK POLICY IF NOT EXISTS IDENTIFIER($vendor_name || '_NETWORK_POLICY')
    ALLOWED_NETWORK_RULE_LIST = (IDENTIFIER('RAW_VENDOR.' || $vendor_name || '.VENDOR_INGRESS_RULE'))
    COMMENT = 'Network policy for vendor ' || $vendor_name || ' users';

----------------------------------------------------------------------
-- 7. Authentication policy (enforce MFA for vendor users)
-- MFA_ENROLLMENT accepts: REQUIRED, REQUIRED_PASSWORD_ONLY, OPTIONAL
-- OPTIONAL is retained for backward compatibility only.
-- REQUIRED_PASSWORD_ONLY enforces MFA only for password-based logins
-- (useful when the same policy covers both human and key-pair users).
----------------------------------------------------------------------
CREATE AUTHENTICATION POLICY IF NOT EXISTS IDENTIFIER('RAW_VENDOR.' || $vendor_name || '.VENDOR_AUTH_POLICY')
    MFA_ENROLLMENT = 'REQUIRED'
    COMMENT        = 'MFA required for vendor ' || $vendor_name || ' users';

----------------------------------------------------------------------
-- 8. Create vendor users (repeat per user)
----------------------------------------------------------------------
-- Example: one vendor engineer
-- Replace with actual usernames and emails.
/*
SET vendor_user    = 'VENDOR_X_ENGINEER_1';
SET vendor_email   = 'engineer@vendorx.com';

CREATE USER IF NOT EXISTS IDENTIFIER($vendor_user)
    DEFAULT_ROLE        = IDENTIFIER($vendor_name || '_INGEST')
    DEFAULT_WAREHOUSE   = IDENTIFIER($vendor_name || '_INGEST_WH')
    EMAIL               = $vendor_email
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT             = 'Vendor ' || $vendor_name || ' engineer';

GRANT ROLE IDENTIFIER($vendor_name || '_INGEST') TO USER IDENTIFIER($vendor_user);

-- Apply network policy to the vendor user
ALTER USER IDENTIFIER($vendor_user) SET NETWORK_POLICY = IDENTIFIER($vendor_name || '_NETWORK_POLICY');

-- Apply authentication policy to the vendor user
ALTER USER IDENTIFIER($vendor_user) SET AUTHENTICATION POLICY
    IDENTIFIER('RAW_VENDOR.' || $vendor_name || '.VENDOR_AUTH_POLICY');
*/

----------------------------------------------------------------------
-- 9. Verification
----------------------------------------------------------------------
SHOW GRANTS TO ROLE IDENTIFIER($vendor_name || '_INGEST');
SHOW GRANTS TO ROLE IDENTIFIER($vendor_name || '_READONLY');
