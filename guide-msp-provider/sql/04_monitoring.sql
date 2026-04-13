/*==============================================================================
MONITORING -- MSP Provider Guide
Queries for cross-account and per-account monitoring.
Run sections as needed; Organisation Usage queries run in MSP_OPS account.
==============================================================================*/

----------------------------------------------------------------------
-- PART A: Organisation-level queries (run in MSP_OPS account)
-- These use SNOWFLAKE.ORGANIZATION_USAGE — no data shares required.
-- PREREQUISITE: These views are only available in the organization
-- account. MSP_OPS must be the org account, or the querying user
-- must hold the ORGADMIN role.
----------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- A1. Credit consumption per account, last 30 days
SELECT
    account_name,
    service_type,
    SUM(credits_used) AS total_credits
FROM SNOWFLAKE.ORGANIZATION_USAGE.METERING_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY account_name, service_type
ORDER BY total_credits DESC;

-- A2. Login activity per account, last 7 days
SELECT
    account_name,
    reported_client_type,
    user_name,
    is_success,
    COUNT(*) AS login_count
FROM SNOWFLAKE.ORGANIZATION_USAGE.LOGIN_HISTORY
WHERE event_timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY account_name, reported_client_type, user_name, is_success
ORDER BY login_count DESC;

-- A3. Warehouse credit burn per account
SELECT
    account_name,
    warehouse_name,
    SUM(credits_used_compute) AS compute_credits
FROM SNOWFLAKE.ORGANIZATION_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY account_name, warehouse_name
ORDER BY compute_credits DESC;

-- A4. Storage per account
SELECT
    account_name,
    ROUND(AVG(storage_bytes) / POWER(1024, 4), 2) AS avg_tb
FROM SNOWFLAKE.ORGANIZATION_USAGE.STORAGE_USAGE
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY account_name
ORDER BY avg_tb DESC;


----------------------------------------------------------------------
-- PART B: Per-account queries (run in each customer account)
----------------------------------------------------------------------
USE ROLE MSP_ACCOUNT_ADMIN;  -- or ACCOUNTADMIN

-- B1. Vendor user login activity, last 7 days
SELECT
    user_name,
    reported_client_type,
    is_success,
    error_message,
    event_timestamp
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND user_name LIKE 'VENDOR_%'
ORDER BY event_timestamp DESC;

-- B2. DDL/DML by vendor roles, last 7 days
SELECT
    user_name,
    role_name,
    query_type,
    query_text,
    start_time,
    execution_status
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND role_name LIKE 'VENDOR_%'
  AND query_type IN ('CREATE', 'ALTER', 'DROP', 'INSERT', 'UPDATE', 'DELETE', 'MERGE', 'COPY')
ORDER BY start_time DESC;

-- B3. Credit use per warehouse (with cost_center tag)
SELECT
    wh.warehouse_name,
    tv.tag_value AS cost_center,
    SUM(wh.credits_used) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY wh
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tv
    ON  tv.object_name = wh.warehouse_name
    AND tv.tag_name    = 'COST_CENTER'
    AND tv.domain      = 'WAREHOUSE'
WHERE wh.start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY wh.warehouse_name, tv.tag_value
ORDER BY total_credits DESC;

-- B4. Failed tasks, last 24 hours
SELECT
    name,
    schema_name,
    database_name,
    state,
    error_message,
    scheduled_time,
    completed_time
FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE scheduled_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
  AND state = 'FAILED'
ORDER BY scheduled_time DESC;

-- B5. Privilege audit — roles with dangerous grants
SELECT
    grantee_name,
    privilege,
    granted_on,
    name AS object_name
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE privilege IN ('OWNERSHIP', 'CREATE SHARE', 'IMPORT SHARE', 'CREATE ACCOUNT', 'MANAGE GRANTS')
  AND grantee_name LIKE 'VENDOR_%'
  AND deleted_on IS NULL;

-- B6. Objects owned by vendor roles (should only be in their RAW_VENDOR schema)
SELECT
    grantee_name AS vendor_role,
    granted_on   AS object_type,
    name         AS object_name,
    table_catalog  AS database_name,
    table_schema   AS schema_name
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE grantee_name LIKE 'VENDOR_%'
  AND privilege = 'OWNERSHIP'
  AND deleted_on IS NULL
  AND table_catalog != 'RAW_VENDOR'
ORDER BY grantee_name, object_type;
