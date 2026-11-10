/*==============================================================================
  Sigma Writeback Walkthrough | Pair-programmed by SE Community + Cortex Code
  Expires: 2027-01-09

  INSTRUCTIONS: Open Snowsight -> New Worksheet -> Paste -> Run All.
  Runtime: under one minute. No edits needed. Safe to re-run.

  WHAT GETS CREATED:
    Roles       SIGMA_SERVICE_ROLE, SIGMA_DATA_CONSUMER
    User        SIGMA_SERVICE_USER (TYPE = SERVICE, no credential yet)
    Warehouse   SFE_SIGMA_WH (XSMALL, auto-suspend 60s)
    Schemas     SNOWFLAKE_EXAMPLE.SIGMA_WRITEBACK  (Sigma's write destination)
                SNOWFLAKE_EXAMPLE.SIGMA_LAB        (a copy of what Sigma writes)
                SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS  (your stable contract layer)
    Task        SIGMA_ANALYTICS.SNAPSHOT_REGION_TARGETS (created SUSPENDED)

  AFTER DEPLOY:
    1. Add a key pair to SIGMA_SERVICE_USER and create the Sigma connection
       (README, "Step 1").
    2. In Sigma, set Write schema to SNOWFLAKE_EXAMPLE.SIGMA_WRITEBACK.
    3. Point SIGMA_ANALYTICS views at the warehouse views Sigma creates.

  PREREQUISITES: ACCOUNTADMIN (creates a user, roles, and an account grant).

  The SIGMA_LAB schema holds a hand-built copy of the storage format observed
  on 2026-11-10. Sigma documents this format as internal and subject to
  change. Never build on real SIGDS_ tables; use warehouse views.
==============================================================================*/

SELECT
    '2027-01-09'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2027-01-09'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2027-01-09'::DATE) < 0
            THEN 'EXPIRED - Sigma behavior may have changed. Re-verify first.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2027-01-09'::DATE) <= 7
            THEN 'EXPIRING SOON - Re-verify against current Sigma docs.'
        ELSE 'ACTIVE'
    END AS guide_status;

-------------------------------------------------------------------------------
-- 1. Identity: one role and one service user for the Sigma connection
-------------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS SIGMA_SERVICE_ROLE
    COMMENT = 'Sigma connection role: reads source data, writes input tables';
CREATE ROLE IF NOT EXISTS SIGMA_DATA_CONSUMER
    COMMENT = 'Reads Sigma-entered data through SIGMA_ANALYTICS only';

-- SYSADMIN inherits the Sigma role so it can own views over Sigma's output.
GRANT ROLE SIGMA_SERVICE_ROLE TO ROLE SYSADMIN;
GRANT ROLE SIGMA_DATA_CONSUMER TO ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SFE_SIGMA_WH
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 600
    COMMENT = 'Sigma queries and input table writes';
GRANT USAGE ON WAREHOUSE SFE_SIGMA_WH TO ROLE SIGMA_SERVICE_ROLE;
GRANT USAGE ON WAREHOUSE SFE_SIGMA_WH TO ROLE SIGMA_DATA_CONSUMER;

-- Sigma stores input tables under mixed-case quoted names such as
-- "SIGDS_2e40...". QUOTED_IDENTIFIERS_IGNORE_CASE = TRUE makes those names
-- unresolvable, so pin it to FALSE on the service user.
CREATE USER IF NOT EXISTS SIGMA_SERVICE_USER
    TYPE = SERVICE
    DEFAULT_ROLE = SIGMA_SERVICE_ROLE
    DEFAULT_WAREHOUSE = SFE_SIGMA_WH
    COMMENT = 'Sigma connection. Add RSA_PUBLIC_KEY before connecting.';
ALTER USER SIGMA_SERVICE_USER SET
    DEFAULT_ROLE = SIGMA_SERVICE_ROLE
    DEFAULT_WAREHOUSE = SFE_SIGMA_WH
    QUOTED_IDENTIFIERS_IGNORE_CASE = FALSE;
GRANT ROLE SIGMA_SERVICE_ROLE TO USER SIGMA_SERVICE_USER;

GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN;

-------------------------------------------------------------------------------
-- 2. A dedicated write schema that Sigma, and nobody else, writes to
-------------------------------------------------------------------------------
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE Community demos and guides';
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SIGMA_WRITEBACK
    COMMENT = 'Sigma write destination. Sigma-managed objects only.';
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SIGMA_LAB
    COMMENT = 'Hand-built copy of the Sigma storage format, for learning';
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS
    COMMENT = 'Stable, typed views over Sigma warehouse views';

-- Privileges Sigma documents for a Snowflake write destination.
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE SIGMA_SERVICE_ROLE;
GRANT USAGE, CREATE TABLE, CREATE VIEW, CREATE STAGE
    ON SCHEMA SNOWFLAKE_EXAMPLE.SIGMA_WRITEBACK TO ROLE SIGMA_SERVICE_ROLE;

-- Consumers never touch SIGMA_WRITEBACK; they read SIGMA_ANALYTICS.
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE SIGMA_DATA_CONSUMER;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS TO ROLE SIGMA_DATA_CONSUMER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS
    TO ROLE SIGMA_DATA_CONSUMER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS
    TO ROLE SIGMA_DATA_CONSUMER;

USE WAREHOUSE SFE_SIGMA_WH;

-------------------------------------------------------------------------------
-- 3. What Sigma writes: one input table "Region / Target / Notes"
--    Same shape as observed live. Column names are random codes, every cell
--    edit adds a row version, deletes add a tombstone, and the clicked-but-
--    empty row is stored as all NULLs.
-------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SNOWFLAKE_EXAMPLE.SIGMA_LAB."SIGDS_00000000_0000_0000_0000_000000000001" (
    ID BINARY,
    SEQ_NUM BINARY,
    ROW_VERSION NUMBER,
    TOMBSTONE_VERSION NUMBER,
    UPDATED_BY TEXT,
    UPDATED_AT TIMESTAMP_LTZ,
    SAKZ1N4J3M TEXT,
    JQZEOOGJ6P TEXT,
    "3HNOK9IT3B" TEXT
);

INSERT INTO SNOWFLAKE_EXAMPLE.SIGMA_LAB."SIGDS_00000000_0000_0000_0000_000000000001"
SELECT TO_BINARY(id_hex, 'HEX'), TO_BINARY(seq_hex, 'HEX'), row_version,
       tombstone_version, 'editor@example.com',
       DATEADD('minute', row_version, '2026-11-10 11:00:00'::TIMESTAMP_LTZ),
       region, target, notes
FROM (VALUES
    ('a1', '01', 1, NULL, NULL,    NULL,  NULL),
    ('a1', '01', 2, NULL, 'West',  NULL,  NULL),
    ('a1', '01', 3, NULL, 'West',  '100', NULL),
    ('a1', '01', 4, NULL, 'West',  '100', 'first'),
    ('b2', '02', 5, NULL, 'East',  NULL,  NULL),
    ('b2', '02', 6, NULL, 'East',  '200', 'second'),
    ('c3', '03', 7, NULL, 'South', '300', 'third'),
    ('a1', '01', 8, NULL, 'West',  '100', 'changed'),
    ('d4', '04', 9, NULL, NULL,    NULL,  NULL),
    ('e5', '05', 10, NULL, 'Test', '1',   'delete me'),
    ('e5', '05', 11, 11,  'Test',  '1',   'delete me')
) AS v (id_hex, seq_hex, row_version, tombstone_version, region, target, notes);

-- 11 stored rows for 4 visible business rows. This is the "ugly" part.
SELECT ID, ROW_VERSION, TOMBSTONE_VERSION, SAKZ1N4J3M, JQZEOOGJ6P, "3HNOK9IT3B"
FROM SNOWFLAKE_EXAMPLE.SIGMA_LAB."SIGDS_00000000_0000_0000_0000_000000000001"
ORDER BY ROW_VERSION;

-------------------------------------------------------------------------------
-- 4. What a Sigma warehouse view looks like
--    Sigma generates this. It keeps the newest version of each row, drops
--    tombstones, renames the codes, and pins a version ceiling. Sigma replaces
--    the whole view after edits, which is why you never build on it directly.
-------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SNOWFLAKE_EXAMPLE.SIGMA_LAB.REGION_TARGETS COPY GRANTS
    COMMENT = 'Stand-in for a Sigma warehouse view (same SQL shape)'
AS
SELECT SAKZ1N4J3M AS REGION, JQZEOOGJ6P AS TARGET, "3HNOK9IT3B" AS NOTES
FROM SNOWFLAKE_EXAMPLE.SIGMA_LAB."SIGDS_00000000_0000_0000_0000_000000000001"
WHERE ROW_VERSION <= 11
QUALIFY ROW_NUMBER() OVER (PARTITION BY ID ORDER BY ROW_VERSION DESC) = 1
    AND TOMBSTONE_VERSION IS NULL;

SELECT REGION, TARGET, NOTES FROM SNOWFLAKE_EXAMPLE.SIGMA_LAB.REGION_TARGETS;

-------------------------------------------------------------------------------
-- 5. Your contract layer: the only thing anyone else should query
--    Real Sigma: replace SNOWFLAKE_EXAMPLE.SIGMA_LAB.REGION_TARGETS with the
--    warehouse view name Sigma shows you.
-------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.REGION_TARGETS
    COMMENT = 'Typed, filtered contract over the Sigma Region Targets input table'
AS
SELECT
    TRIM(REGION)::VARCHAR(50) AS REGION,
    TRY_TO_NUMBER(TARGET, 38, 2) AS TARGET_AMOUNT,
    NOTES::VARCHAR(1000) AS NOTES
FROM SNOWFLAKE_EXAMPLE.SIGMA_LAB.REGION_TARGETS
WHERE REGION IS NOT NULL;

SELECT REGION, TARGET_AMOUNT, NOTES
FROM SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.REGION_TARGETS
ORDER BY REGION;

-------------------------------------------------------------------------------
-- 6. Optional: point-in-time history
--    A warehouse view only shows the current state. If you need "what did
--    the plan say on Friday", snapshot it on a schedule.
-------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.REGION_TARGETS_HISTORY (
    SNAPSHOT_AT TIMESTAMP_LTZ,
    REGION VARCHAR(50),
    TARGET_AMOUNT NUMBER(38, 2),
    NOTES VARCHAR(1000)
);

CREATE OR REPLACE TASK SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.SNAPSHOT_REGION_TARGETS
    WAREHOUSE = SFE_SIGMA_WH
    SCHEDULE = 'USING CRON 0 18 * * * UTC'
    COMMENT = 'Daily snapshot of Sigma-entered targets'
AS
INSERT INTO SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.REGION_TARGETS_HISTORY
SELECT CURRENT_TIMESTAMP(), REGION, TARGET_AMOUNT, NOTES
FROM SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.REGION_TARGETS;

-- Take one snapshot now (each re-run adds one more). The task stays
-- suspended until you resume it:
-- ALTER TASK SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.SNAPSHOT_REGION_TARGETS RESUME;
INSERT INTO SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.REGION_TARGETS_HISTORY
SELECT CURRENT_TIMESTAMP(), REGION, TARGET_AMOUNT, NOTES
FROM SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.REGION_TARGETS;

-------------------------------------------------------------------------------
-- 7. Inventory: what Sigma has written to a write schema
--    Swap SIGMA_LAB for your write schema. SIGDS_ tables that stopped
--    changing long ago are candidates for an input table someone deleted
--    in Sigma; Sigma does not drop the data.
-------------------------------------------------------------------------------
SELECT
    TABLE_NAME,
    CASE
        WHEN STARTSWITH(TABLE_NAME, 'SIGDS_WAL_') THEN 'edit log'
        WHEN STARTSWITH(TABLE_NAME, 'SIGDS_') THEN 'input table data'
        WHEN STARTSWITH(TABLE_NAME, 'INPUT_TABLE_AUDIT_LOG_') THEN 'audit log view'
        WHEN COMMENT ILIKE 'Created by % in Sigma%' THEN 'warehouse view'
        ELSE 'other'
    END AS SIGMA_OBJECT_KIND,
    TABLE_TYPE,
    ROW_COUNT,
    LAST_ALTERED,
    DATEDIFF('day', LAST_ALTERED, CURRENT_TIMESTAMP()) AS DAYS_SINCE_CHANGE
FROM SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SIGMA_LAB'
ORDER BY SIGMA_OBJECT_KIND, TABLE_NAME;

-------------------------------------------------------------------------------
-- 8. Validation
-------------------------------------------------------------------------------
SELECT
    'Sigma writeback walkthrough' AS guide,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.SIGMA_LAB."SIGDS_00000000_0000_0000_0000_000000000001") AS stored_versions,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.SIGMA_LAB.REGION_TARGETS) AS warehouse_view_rows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.REGION_TARGETS) AS contract_rows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.SIGMA_ANALYTICS.REGION_TARGETS_HISTORY) AS snapshot_rows,
    'Add a key pair to SIGMA_SERVICE_USER, then connect Sigma (README Step 1)' AS next_step;
