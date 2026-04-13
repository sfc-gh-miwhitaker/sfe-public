/*==============================================================================
ACCOUNT BASELINE -- MSP Provider Guide
Reference script: adapt names and parameters to your environment.
Run as ACCOUNTADMIN in each new customer account.
==============================================================================*/

----------------------------------------------------------------------
-- 0. Session config
----------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

----------------------------------------------------------------------
-- 1. MSP roles
----------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS MSP_ACCOUNT_ADMIN
    COMMENT = 'MSP top-level admin — granted ACCOUNTADMIN';
CREATE ROLE IF NOT EXISTS MSP_SECURITY_ADMIN
    COMMENT = 'MSP security — users, roles, network policies';
CREATE ROLE IF NOT EXISTS MSP_PLATFORM_ENGINEER
    COMMENT = 'MSP platform — warehouses, databases, pipelines';

GRANT ROLE ACCOUNTADMIN   TO ROLE MSP_ACCOUNT_ADMIN;
GRANT ROLE SECURITYADMIN  TO ROLE MSP_SECURITY_ADMIN;
GRANT ROLE SYSADMIN       TO ROLE MSP_PLATFORM_ENGINEER;

-- Wire custom roles into the system hierarchy so ACCOUNTADMIN
-- can always manage objects they create.
GRANT ROLE MSP_PLATFORM_ENGINEER TO ROLE MSP_SECURITY_ADMIN;
GRANT ROLE MSP_SECURITY_ADMIN    TO ROLE MSP_ACCOUNT_ADMIN;

----------------------------------------------------------------------
-- 2. Customer roles
----------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS CUST_ADMIN
    COMMENT = 'Customer admin — limited user/role management via stored procedures';
CREATE ROLE IF NOT EXISTS CUST_ANALYST
    COMMENT = 'Customer analyst — read access to PRESENTATION layer';

GRANT ROLE CUST_ANALYST TO ROLE CUST_ADMIN;
GRANT ROLE CUST_ADMIN   TO ROLE MSP_PLATFORM_ENGINEER;

----------------------------------------------------------------------
-- 3. Databases
----------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS RAW_INTERNAL
    COMMENT = 'Customer-owned raw sources';
CREATE DATABASE IF NOT EXISTS RAW_VENDOR
    COMMENT = 'Vendor raw landing — one schema per vendor';
CREATE DATABASE IF NOT EXISTS INTEGRATION
    COMMENT = 'Business logic, joins, harmonisation';
CREATE DATABASE IF NOT EXISTS PRESENTATION
    COMMENT = 'Curated outputs for BI and apps';
CREATE DATABASE IF NOT EXISTS WORKSPACE
    COMMENT = 'Experiments and support work';

----------------------------------------------------------------------
-- 4. Schemas (WITH MANAGED ACCESS where vendors create objects)
----------------------------------------------------------------------
-- RAW_INTERNAL
CREATE SCHEMA IF NOT EXISTS RAW_INTERNAL.SRC_PLACEHOLDER
    COMMENT = 'Replace with actual source system name';

-- RAW_VENDOR: vendor schemas created by 02_vendor_onboard.sql
-- Using MANAGED ACCESS so only the schema owner (MSP) controls grants,
-- even when vendors own the objects they create.

-- INTEGRATION
CREATE SCHEMA IF NOT EXISTS INTEGRATION.CORE
    WITH MANAGED ACCESS
    COMMENT = 'Business logic and harmonised models';

-- PRESENTATION
CREATE SCHEMA IF NOT EXISTS PRESENTATION.ANALYTICS
    WITH MANAGED ACCESS
    COMMENT = 'Curated tables/views for BI';
CREATE SCHEMA IF NOT EXISTS PRESENTATION.API
    WITH MANAGED ACCESS
    COMMENT = 'App-facing views, secure views for vendor read-back';

-- WORKSPACE
CREATE SCHEMA IF NOT EXISTS WORKSPACE.MSP
    COMMENT = 'MSP experiments and support work';
CREATE SCHEMA IF NOT EXISTS WORKSPACE.CUST
    COMMENT = 'Customer sandbox';

----------------------------------------------------------------------
-- 5. Warehouses
----------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS MSP_ELT_WH
    WAREHOUSE_SIZE      = 'SMALL'
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT             = 'MSP pipelines and heavy integration';

CREATE WAREHOUSE IF NOT EXISTS CUST_ANALYTICS_WH
    WAREHOUSE_SIZE      = 'XSMALL'
    AUTO_SUSPEND        = 120
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT             = 'Customer analysts and BI tools';

----------------------------------------------------------------------
-- 6. Resource monitors
----------------------------------------------------------------------
CREATE RESOURCE MONITOR IF NOT EXISTS ACCOUNT_MONITOR
    WITH CREDIT_QUOTA = 500
    FREQUENCY         = MONTHLY
    START_TIMESTAMP   = IMMEDIATELY
    TRIGGERS
        ON 80 PERCENT DO NOTIFY
        ON 95 PERCENT DO SUSPEND
        ON 100 PERCENT DO SUSPEND_IMMEDIATE;

ALTER ACCOUNT SET RESOURCE_MONITOR = ACCOUNT_MONITOR;

CREATE RESOURCE MONITOR IF NOT EXISTS CUST_ANALYTICS_MONITOR
    WITH CREDIT_QUOTA = 100
    FREQUENCY         = MONTHLY
    START_TIMESTAMP   = IMMEDIATELY
    TRIGGERS
        ON 80 PERCENT DO NOTIFY
        ON 95 PERCENT DO SUSPEND;

ALTER WAREHOUSE CUST_ANALYTICS_WH SET RESOURCE_MONITOR = CUST_ANALYTICS_MONITOR;

----------------------------------------------------------------------
-- 7. Base grants — MSP roles
----------------------------------------------------------------------
-- MSP_PLATFORM_ENGINEER owns pipelines
GRANT USAGE   ON DATABASE RAW_INTERNAL  TO ROLE MSP_PLATFORM_ENGINEER;
GRANT USAGE   ON DATABASE RAW_VENDOR    TO ROLE MSP_PLATFORM_ENGINEER;
GRANT USAGE   ON DATABASE INTEGRATION   TO ROLE MSP_PLATFORM_ENGINEER;
GRANT USAGE   ON DATABASE PRESENTATION  TO ROLE MSP_PLATFORM_ENGINEER;
GRANT USAGE   ON DATABASE WORKSPACE     TO ROLE MSP_PLATFORM_ENGINEER;

GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE RAW_INTERNAL  TO ROLE MSP_PLATFORM_ENGINEER;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE RAW_VENDOR    TO ROLE MSP_PLATFORM_ENGINEER;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE INTEGRATION   TO ROLE MSP_PLATFORM_ENGINEER;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE PRESENTATION  TO ROLE MSP_PLATFORM_ENGINEER;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE WORKSPACE     TO ROLE MSP_PLATFORM_ENGINEER;

GRANT USAGE   ON WAREHOUSE MSP_ELT_WH        TO ROLE MSP_PLATFORM_ENGINEER;
GRANT OPERATE ON WAREHOUSE MSP_ELT_WH        TO ROLE MSP_PLATFORM_ENGINEER;
GRANT USAGE   ON WAREHOUSE CUST_ANALYTICS_WH  TO ROLE MSP_PLATFORM_ENGINEER;

----------------------------------------------------------------------
-- 8. Base grants — customer roles
----------------------------------------------------------------------
GRANT USAGE ON DATABASE PRESENTATION TO ROLE CUST_ANALYST;
GRANT USAGE ON SCHEMA PRESENTATION.ANALYTICS TO ROLE CUST_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA PRESENTATION.ANALYTICS TO ROLE CUST_ANALYST;
GRANT SELECT ON ALL VIEWS  IN SCHEMA PRESENTATION.ANALYTICS TO ROLE CUST_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA PRESENTATION.ANALYTICS TO ROLE CUST_ANALYST;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA PRESENTATION.ANALYTICS TO ROLE CUST_ANALYST;

GRANT USAGE ON WAREHOUSE CUST_ANALYTICS_WH TO ROLE CUST_ANALYST;

GRANT USAGE ON DATABASE WORKSPACE TO ROLE CUST_ADMIN;
GRANT USAGE ON SCHEMA WORKSPACE.CUST TO ROLE CUST_ADMIN;
GRANT ALL PRIVILEGES ON SCHEMA WORKSPACE.CUST TO ROLE CUST_ADMIN;

----------------------------------------------------------------------
-- 9. Object tags for cost attribution
----------------------------------------------------------------------
CREATE TAG IF NOT EXISTS RAW_INTERNAL.PUBLIC.COST_CENTER
    ALLOWED_VALUES 'msp', 'customer', 'vendor'
    COMMENT = 'Cost attribution tag for warehouses and queries';

ALTER WAREHOUSE MSP_ELT_WH
    SET TAG RAW_INTERNAL.PUBLIC.COST_CENTER = 'msp';
ALTER WAREHOUSE CUST_ANALYTICS_WH
    SET TAG RAW_INTERNAL.PUBLIC.COST_CENTER = 'customer';

----------------------------------------------------------------------
-- 10. Delegated user management for CUST_ADMIN (stored procedure)
--     This avoids granting CREATE USER / CREATE ROLE directly.
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE WORKSPACE.MSP.CREATE_CUSTOMER_USER(
    p_username       VARCHAR,
    p_default_role   VARCHAR,
    p_email          VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
    -- Only allow customer-scoped default roles
    IF (:p_default_role NOT IN ('CUST_ADMIN', 'CUST_ANALYST')) THEN
        RETURN 'ERROR: default_role must be CUST_ADMIN or CUST_ANALYST';
    END IF;

    -- Reject usernames containing characters that could enable SQL injection
    IF (:p_username RLIKE '.*[^A-Za-z0-9_].*') THEN
        RETURN 'ERROR: username must be alphanumeric/underscores only';
    END IF;

    -- Reject email with single quotes or semicolons
    IF (:p_email LIKE '%''%' OR :p_email LIKE '%;%') THEN
        RETURN 'ERROR: email contains invalid characters';
    END IF;

    EXECUTE IMMEDIATE
        'CREATE USER IF NOT EXISTS IDENTIFIER(''' || :p_username || ''')'  ||
        ' DEFAULT_ROLE = ' || :p_default_role ||
        ' EMAIL = ''' || :p_email || '''' ||
        ' MUST_CHANGE_PASSWORD = TRUE' ||
        ' COMMENT = ''Created by CUST_ADMIN delegation''';

    EXECUTE IMMEDIATE
        'GRANT ROLE ' || :p_default_role ||
        ' TO USER IDENTIFIER(''' || :p_username || ''')';

    RETURN 'User ' || :p_username || ' created with role ' || :p_default_role;
END;
$$;

GRANT USAGE ON PROCEDURE WORKSPACE.MSP.CREATE_CUSTOMER_USER(VARCHAR, VARCHAR, VARCHAR)
    TO ROLE CUST_ADMIN;
