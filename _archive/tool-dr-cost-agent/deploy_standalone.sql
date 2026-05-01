/******************************************************************************
 * Tool: DR Cost Agent (Snowflake Intelligence)
 * File: deploy_standalone.sql  (SELF-CONTAINED -- no Git integration needed)
 * Author: SE Community
 * Created: 2025-12-08
 * Last Updated: 2026-03-17
 * Expires: 2026-05-01
 *
 * Prerequisites:
 *   SYSADMIN role access (ACCOUNTADMIN only for USAGE_VIEWER grant)
 *
 * How to Deploy:
 *   1. Copy this ENTIRE script into a Snowsight worksheet
 *   2. Click "Run All"
 *   3. Open Snowflake Intelligence -> DR Cost Estimator
 *
 * What This Creates:
 *   - Database: SNOWFLAKE_EXAMPLE (if not exists)
 *   - Schema: SNOWFLAKE_EXAMPLE.DR_COST_AGENT
 *   - Table: PRICING_CURRENT (60 baseline pricing rows)
 *   - Views: DB_METADATA_V2, HYBRID_TABLE_METADATA, REPLICATION_HISTORY
 *   - Procedures: COST_PROJECTION (agent tool), UPDATE_PRICING (admin)
 *   - Semantic View: SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST
 *   - Agent: DR_COST_AGENT (Snowflake Intelligence)
 *
 * NOTE: This is the standalone version. For Git-integrated deployment
 *       (automatic updates when the repo changes), use deploy.sql instead.
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK
-- ============================================================================
SELECT
    '2026-05-01'::DATE AS expiration_date,
    CURRENT_DATE() AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-05-01'::DATE) || ' days remaining'
    END AS tool_status;

-- ============================================================================
-- 01: SCHEMA & WAREHOUSE
-- ============================================================================
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_TOOLS_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Shared warehouse for Snowflake Tools Collection | Author: SE Community';
USE WAREHOUSE SFE_TOOLS_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.DR_COST_AGENT
    COMMENT = 'TOOL: DR/replication cost estimation agent (Expires: 2026-05-01)';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
    COMMENT = 'Shared schema for semantic views across demo projects | Author: SE Community';

USE SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT;

-- ============================================================================
-- 02: PRICING TABLE & SEED DATA
-- ============================================================================
CREATE OR REPLACE TABLE PRICING_CURRENT (
    SERVICE_TYPE STRING    NOT NULL,
    CLOUD        STRING    NOT NULL,
    REGION       STRING    NOT NULL,
    UNIT         STRING    NOT NULL,
    RATE         NUMBER(10,4) NOT NULL,
    CURRENCY     STRING    DEFAULT 'CREDITS',
    UPDATED_AT   TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY   STRING    DEFAULT CURRENT_USER(),
    CONSTRAINT pk_pricing PRIMARY KEY (SERVICE_TYPE, CLOUD, REGION, UNIT)
) COMMENT = 'TOOL: Replication pricing rates (BC baseline) - Expires: 2026-05-01';

INSERT INTO PRICING_CURRENT (SERVICE_TYPE, CLOUD, REGION, UNIT, RATE, CURRENCY) VALUES
    -- AWS Regions
    ('DATA_TRANSFER',       'AWS',   'us-east-1',        'TB',       2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS',   'us-east-1',        'TB',       1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AWS',   'us-east-1',        'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AWS',   'us-east-1',        'TB_MONTH', 0.10, 'CREDITS'),
    ('HYBRID_STORAGE',      'AWS',   'us-east-1',        'GB_MONTH', 0.06, 'CREDITS'),
    ('DATA_TRANSFER',       'AWS',   'us-west-2',        'TB',       2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS',   'us-west-2',        'TB',       1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AWS',   'us-west-2',        'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AWS',   'us-west-2',        'TB_MONTH', 0.10, 'CREDITS'),
    ('HYBRID_STORAGE',      'AWS',   'us-west-2',        'GB_MONTH', 0.06, 'CREDITS'),
    ('DATA_TRANSFER',       'AWS',   'eu-west-1',        'TB',       2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS',   'eu-west-1',        'TB',       1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AWS',   'eu-west-1',        'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AWS',   'eu-west-1',        'TB_MONTH', 0.10, 'CREDITS'),
    ('HYBRID_STORAGE',      'AWS',   'eu-west-1',        'GB_MONTH', 0.06, 'CREDITS'),
    ('DATA_TRANSFER',       'AWS',   'ap-southeast-1',   'TB',       2.50, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AWS',   'ap-southeast-1',   'TB',       1.00, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AWS',   'ap-southeast-1',   'TB_MONTH', 0.25, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AWS',   'ap-southeast-1',   'TB_MONTH', 0.10, 'CREDITS'),
    ('HYBRID_STORAGE',      'AWS',   'ap-southeast-1',   'GB_MONTH', 0.06, 'CREDITS'),
    -- Azure Regions
    ('DATA_TRANSFER',       'AZURE', 'eastus2',          'TB',       2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'eastus2',          'TB',       1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AZURE', 'eastus2',          'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AZURE', 'eastus2',          'TB_MONTH', 0.12, 'CREDITS'),
    ('HYBRID_STORAGE',      'AZURE', 'eastus2',          'GB_MONTH', 0.07, 'CREDITS'),
    ('DATA_TRANSFER',       'AZURE', 'westus2',          'TB',       2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'westus2',          'TB',       1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AZURE', 'westus2',          'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AZURE', 'westus2',          'TB_MONTH', 0.12, 'CREDITS'),
    ('HYBRID_STORAGE',      'AZURE', 'westus2',          'GB_MONTH', 0.07, 'CREDITS'),
    ('DATA_TRANSFER',       'AZURE', 'westeurope',       'TB',       2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'westeurope',       'TB',       1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AZURE', 'westeurope',       'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AZURE', 'westeurope',       'TB_MONTH', 0.12, 'CREDITS'),
    ('HYBRID_STORAGE',      'AZURE', 'westeurope',       'GB_MONTH', 0.07, 'CREDITS'),
    ('DATA_TRANSFER',       'AZURE', 'southeastasia',    'TB',       2.70, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'AZURE', 'southeastasia',    'TB',       1.10, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'AZURE', 'southeastasia',    'TB_MONTH', 0.27, 'CREDITS'),
    ('SERVERLESS_MAINT',    'AZURE', 'southeastasia',    'TB_MONTH', 0.12, 'CREDITS'),
    ('HYBRID_STORAGE',      'AZURE', 'southeastasia',    'GB_MONTH', 0.07, 'CREDITS'),
    -- GCP Regions
    ('DATA_TRANSFER',       'GCP',   'us-central1',      'TB',       2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP',   'us-central1',      'TB',       1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'GCP',   'us-central1',      'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT',    'GCP',   'us-central1',      'TB_MONTH', 0.11, 'CREDITS'),
    ('HYBRID_STORAGE',      'GCP',   'us-central1',      'GB_MONTH', 0.065, 'CREDITS'),
    ('DATA_TRANSFER',       'GCP',   'us-west1',         'TB',       2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP',   'us-west1',         'TB',       1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'GCP',   'us-west1',         'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT',    'GCP',   'us-west1',         'TB_MONTH', 0.11, 'CREDITS'),
    ('HYBRID_STORAGE',      'GCP',   'us-west1',         'GB_MONTH', 0.065, 'CREDITS'),
    ('DATA_TRANSFER',       'GCP',   'europe-west1',     'TB',       2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP',   'europe-west1',     'TB',       1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'GCP',   'europe-west1',     'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT',    'GCP',   'europe-west1',     'TB_MONTH', 0.11, 'CREDITS'),
    ('HYBRID_STORAGE',      'GCP',   'europe-west1',     'GB_MONTH', 0.065, 'CREDITS'),
    ('DATA_TRANSFER',       'GCP',   'asia-southeast1',  'TB',       2.60, 'CREDITS'),
    ('REPLICATION_COMPUTE', 'GCP',   'asia-southeast1',  'TB',       1.05, 'CREDITS'),
    ('STORAGE_TB_MONTH',    'GCP',   'asia-southeast1',  'TB_MONTH', 0.26, 'CREDITS'),
    ('SERVERLESS_MAINT',    'GCP',   'asia-southeast1',  'TB_MONTH', 0.11, 'CREDITS'),
    ('HYBRID_STORAGE',      'GCP',   'asia-southeast1',  'GB_MONTH', 0.065, 'CREDITS');

-- ============================================================================
-- 03: VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW DB_METADATA_V2
    COMMENT = 'TOOL: Database sizes with hybrid table exclusion for replication sizing (Expires: 2026-05-01)'
AS
WITH ALL_DBS AS (
    SELECT DATABASE_NAME
    FROM INFORMATION_SCHEMA.DATABASES
    WHERE DATABASE_NAME NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA', 'UTIL_DB')
),
DB_STORAGE AS (
    SELECT
        TABLE_CATALOG AS DATABASE_NAME,
        SUM(ACTIVE_BYTES) AS TOTAL_BYTES
    FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
    WHERE TABLE_CATALOG NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA', 'UTIL_DB')
      AND DELETED IS NULL
    GROUP BY TABLE_CATALOG
),
HYBRID_STORAGE AS (
    SELECT
        TABLE_CATALOG AS DATABASE_NAME,
        COUNT(*) AS HYBRID_TABLE_COUNT,
        COALESCE(SUM(BYTES), 0) AS HYBRID_TABLE_BYTES
    FROM SNOWFLAKE.ACCOUNT_USAGE.HYBRID_TABLES
    WHERE DELETED IS NULL
    GROUP BY TABLE_CATALOG
)
SELECT
    d.DATABASE_NAME,
    COALESCE((s.TOTAL_BYTES / POWER(1024, 4)), 0)::NUMBER(18,6) AS TOTAL_SIZE_TB,
    COALESCE((h.HYBRID_TABLE_BYTES / POWER(1024, 4)), 0)::NUMBER(18,6) AS HYBRID_EXCLUDED_TB,
    (COALESCE((s.TOTAL_BYTES / POWER(1024, 4)), 0)
     - COALESCE((h.HYBRID_TABLE_BYTES / POWER(1024, 4)), 0))::NUMBER(18,6) AS REPLICABLE_SIZE_TB,
    COALESCE(h.HYBRID_TABLE_COUNT, 0) AS HYBRID_TABLE_COUNT,
    CASE WHEN COALESCE(h.HYBRID_TABLE_COUNT, 0) > 0 THEN TRUE ELSE FALSE END AS HAS_HYBRID_TABLES,
    CURRENT_TIMESTAMP() AS QUERIED_AT,
    DATEDIFF('hour',
        (SELECT MAX(LAST_ALTERED) FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
         WHERE DELETED IS NULL),
        CURRENT_TIMESTAMP()
    ) AS DATA_STALENESS_HOURS
FROM ALL_DBS d
LEFT JOIN DB_STORAGE s ON d.DATABASE_NAME = s.DATABASE_NAME
LEFT JOIN HYBRID_STORAGE h ON d.DATABASE_NAME = h.DATABASE_NAME;

CREATE OR REPLACE VIEW HYBRID_TABLE_METADATA
    COMMENT = 'TOOL: Hybrid table inventory per database -- excluded from replication (Expires: 2026-05-01)'
AS
SELECT
    TABLE_CATALOG AS DATABASE_NAME,
    TABLE_SCHEMA,
    TABLE_NAME,
    BYTES,
    (BYTES / POWER(1024, 3))::NUMBER(18,4) AS SIZE_GB,
    CREATED AS CREATED_AT,
    LAST_ALTERED AS LAST_ALTERED_AT,
    CURRENT_TIMESTAMP() AS AS_OF
FROM SNOWFLAKE.ACCOUNT_USAGE.HYBRID_TABLES
WHERE DELETED IS NULL;

CREATE OR REPLACE VIEW REPLICATION_HISTORY
    COMMENT = 'TOOL: Actual replication costs from ACCOUNT_USAGE (Expires: 2026-05-01)'
AS
SELECT
    REPLICATION_GROUP_NAME,
    REPLICATION_GROUP_ID,
    START_TIME,
    END_TIME,
    DATE_TRUNC('day', START_TIME)::DATE AS USAGE_DATE,
    DATE_TRUNC('month', START_TIME)::DATE AS USAGE_MONTH,
    CREDITS_USED,
    BYTES_TRANSFERRED,
    (BYTES_TRANSFERRED / POWER(1024, 4))::NUMBER(18,6) AS TB_TRANSFERRED
FROM SNOWFLAKE.ACCOUNT_USAGE.REPLICATION_GROUP_USAGE_HISTORY;

-- ============================================================================
-- 04: PROCEDURES
-- ============================================================================

CREATE OR REPLACE PROCEDURE COST_PROJECTION(
    DB_FILTER      STRING,
    DEST_CLOUD     STRING,
    DEST_REGION    STRING,
    CHANGE_PCT     FLOAT,
    REFRESHES_DAY  FLOAT,
    CREDIT_PRICE   FLOAT
)
RETURNS TABLE (
    COMPONENT         STRING,
    DAILY_CREDITS     FLOAT,
    MONTHLY_CREDITS   FLOAT,
    ANNUAL_CREDITS    FLOAT,
    MONTHLY_USD       FLOAT,
    ANNUAL_USD        FLOAT,
    NOTE              STRING
)
LANGUAGE SQL
COMMENT = 'TOOL: DR replication cost projection with hybrid table exclusion (Expires: 2026-05-01)'
AS
DECLARE
    res RESULTSET;
BEGIN
    res := (
        WITH source_region AS (
            SELECT
                SPLIT_PART(CURRENT_REGION(), '_', 1) AS SRC_CLOUD,
                LOWER(REPLACE(
                    SUBSTR(CURRENT_REGION(),
                           POSITION('_' IN CURRENT_REGION()) + 1),
                    '_', '-'
                )) AS SRC_REGION
        ),
        db_sizes AS (
            SELECT
                SUM(REPLICABLE_SIZE_TB) AS REPLICABLE_TB,
                SUM(TOTAL_SIZE_TB) AS TOTAL_TB,
                SUM(HYBRID_EXCLUDED_TB) AS HYBRID_TB,
                SUM(HYBRID_TABLE_COUNT) AS HYBRID_COUNT
            FROM SNOWFLAKE_EXAMPLE.DR_COST_AGENT.DB_METADATA_V2
            WHERE :DB_FILTER = 'ALL'
               OR DATABASE_NAME IN (
                    SELECT TRIM(VALUE)
                    FROM TABLE(SPLIT_TO_TABLE(:DB_FILTER, ','))
                  )
        ),
        rates AS (
            SELECT
                MAX(CASE WHEN SERVICE_TYPE = 'DATA_TRANSFER'
                          AND CLOUD = sr.SRC_CLOUD
                     THEN RATE END) AS TRANSFER_RATE,
                MAX(CASE WHEN SERVICE_TYPE = 'REPLICATION_COMPUTE'
                          AND CLOUD = sr.SRC_CLOUD
                     THEN RATE END) AS COMPUTE_RATE,
                MAX(CASE WHEN SERVICE_TYPE = 'STORAGE_TB_MONTH'
                          AND CLOUD = :DEST_CLOUD
                          AND UPPER(REGION) = UPPER(:DEST_REGION)
                     THEN RATE END) AS STORAGE_RATE,
                MAX(CASE WHEN SERVICE_TYPE = 'SERVERLESS_MAINT'
                          AND CLOUD = :DEST_CLOUD
                          AND UPPER(REGION) = UPPER(:DEST_REGION)
                     THEN RATE END) AS SERVERLESS_RATE,
                MAX(CASE WHEN SERVICE_TYPE = 'HYBRID_STORAGE'
                          AND CLOUD = :DEST_CLOUD
                          AND UPPER(REGION) = UPPER(:DEST_REGION)
                     THEN RATE END) AS HYBRID_STORAGE_RATE
            FROM SNOWFLAKE_EXAMPLE.DR_COST_AGENT.PRICING_CURRENT p
            CROSS JOIN source_region sr
        ),
        calcs AS (
            SELECT
                d.REPLICABLE_TB,
                d.TOTAL_TB,
                d.HYBRID_TB,
                d.HYBRID_COUNT,
                d.REPLICABLE_TB * (:CHANGE_PCT / 100.0) * :REFRESHES_DAY AS DAILY_TRANSFER_TB,
                r.TRANSFER_RATE,
                r.COMPUTE_RATE,
                r.STORAGE_RATE,
                r.SERVERLESS_RATE,
                r.HYBRID_STORAGE_RATE
            FROM db_sizes d
            CROSS JOIN rates r
        )
        SELECT COMPONENT, DAILY_CREDITS, MONTHLY_CREDITS, ANNUAL_CREDITS,
               MONTHLY_CREDITS * :CREDIT_PRICE AS MONTHLY_USD,
               ANNUAL_CREDITS  * :CREDIT_PRICE AS ANNUAL_USD,
               NOTE
        FROM (
            SELECT '** DATA FRESHNESS **' AS COMPONENT,
                   0 AS DAILY_CREDITS, 0 AS MONTHLY_CREDITS, 0 AS ANNUAL_CREDITS,
                   'Storage metrics sourced from ACCOUNT_USAGE (up to 3-hour lag). '
                   || 'Queried at ' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYY-MM-DD HH24:MI TZH:TZM') AS NOTE
            UNION ALL
            SELECT '** HYBRID WARNING **',
                   0, 0, 0,
                   c.HYBRID_COUNT || ' hybrid table(s) totaling '
                   || ROUND(c.HYBRID_TB, 6) || ' TB are EXCLUDED from replication '
                   || '(silently skipped per BCR-1560-1582). '
                   || 'Replicable size is ' || ROUND(c.REPLICABLE_TB, 6) || ' TB '
                   || 'out of ' || ROUND(c.TOTAL_TB, 6) || ' TB total.'
            FROM calcs c
            WHERE c.HYBRID_COUNT > 0
            UNION ALL
            SELECT 'Data Transfer' AS COMPONENT,
                   c.DAILY_TRANSFER_TB * COALESCE(c.TRANSFER_RATE, 0) AS DAILY_CREDITS,
                   c.DAILY_TRANSFER_TB * COALESCE(c.TRANSFER_RATE, 0) * 30 AS MONTHLY_CREDITS,
                   c.DAILY_TRANSFER_TB * COALESCE(c.TRANSFER_RATE, 0) * 365 AS ANNUAL_CREDITS,
                   CASE WHEN c.TRANSFER_RATE IS NULL
                        THEN 'No exact rate found for source region; using zero'
                        ELSE NULL END AS NOTE
            FROM calcs c
            UNION ALL
            SELECT 'Replication Compute',
                   c.DAILY_TRANSFER_TB * COALESCE(c.COMPUTE_RATE, 0),
                   c.DAILY_TRANSFER_TB * COALESCE(c.COMPUTE_RATE, 0) * 30,
                   c.DAILY_TRANSFER_TB * COALESCE(c.COMPUTE_RATE, 0) * 365,
                   CASE WHEN c.COMPUTE_RATE IS NULL
                        THEN 'No exact rate found for source region; using zero'
                        ELSE NULL END
            FROM calcs c
            UNION ALL
            SELECT 'Secondary Storage',
                   0,
                   c.REPLICABLE_TB * COALESCE(c.STORAGE_RATE, 0),
                   c.REPLICABLE_TB * COALESCE(c.STORAGE_RATE, 0) * 12,
                   CASE WHEN c.STORAGE_RATE IS NULL
                        THEN 'No rate for destination region; using zero'
                        ELSE NULL END
            FROM calcs c
            UNION ALL
            SELECT 'Serverless Maintenance',
                   0,
                   c.REPLICABLE_TB * COALESCE(c.SERVERLESS_RATE, 0),
                   c.REPLICABLE_TB * COALESCE(c.SERVERLESS_RATE, 0) * 12,
                   CASE WHEN c.SERVERLESS_RATE IS NULL
                        THEN 'No rate for destination region; using zero'
                        ELSE NULL END
            FROM calcs c
            UNION ALL
            SELECT 'Hybrid Table Storage (dest)',
                   0,
                   c.HYBRID_TB * 1024 * COALESCE(c.HYBRID_STORAGE_RATE, 0),
                   c.HYBRID_TB * 1024 * COALESCE(c.HYBRID_STORAGE_RATE, 0) * 12,
                   CASE WHEN c.HYBRID_COUNT > 0
                        THEN c.HYBRID_COUNT || ' hybrid table(s) excluded from replication; storage re-created at destination if needed'
                        ELSE 'No hybrid tables in selected databases' END
            FROM calcs c
            UNION ALL
            SELECT '--- TOTAL ---',
                   SUM(DAILY_CREDITS),
                   SUM(MONTHLY_CREDITS),
                   SUM(ANNUAL_CREDITS),
                   NULL
            FROM (
                SELECT c.DAILY_TRANSFER_TB * COALESCE(c.TRANSFER_RATE, 0)
                     + c.DAILY_TRANSFER_TB * COALESCE(c.COMPUTE_RATE, 0) AS DAILY_CREDITS,
                       (c.DAILY_TRANSFER_TB * COALESCE(c.TRANSFER_RATE, 0)
                      + c.DAILY_TRANSFER_TB * COALESCE(c.COMPUTE_RATE, 0)) * 30
                      + c.REPLICABLE_TB * COALESCE(c.STORAGE_RATE, 0)
                      + c.REPLICABLE_TB * COALESCE(c.SERVERLESS_RATE, 0)
                      + c.HYBRID_TB * 1024 * COALESCE(c.HYBRID_STORAGE_RATE, 0) AS MONTHLY_CREDITS,
                       (c.DAILY_TRANSFER_TB * COALESCE(c.TRANSFER_RATE, 0)
                      + c.DAILY_TRANSFER_TB * COALESCE(c.COMPUTE_RATE, 0)) * 365
                      + (c.REPLICABLE_TB * COALESCE(c.STORAGE_RATE, 0)
                      +  c.REPLICABLE_TB * COALESCE(c.SERVERLESS_RATE, 0)
                      +  c.HYBRID_TB * 1024 * COALESCE(c.HYBRID_STORAGE_RATE, 0)) * 12 AS ANNUAL_CREDITS
                FROM calcs c
            ) totals
        )
        ORDER BY CASE WHEN COMPONENT LIKE '** %' THEN 0
                      WHEN COMPONENT = '--- TOTAL ---' THEN 2
                      ELSE 1 END,
                 COMPONENT
    );
    RETURN TABLE(res);
END;

CREATE OR REPLACE PROCEDURE UPDATE_PRICING(
    P_SERVICE_TYPE STRING,
    P_CLOUD        STRING,
    P_REGION       STRING,
    P_RATE         FLOAT
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'TOOL: Update or insert a pricing rate for DR cost estimation (Expires: 2026-05-01)'
AS
DECLARE
    v_unit STRING;
BEGIN
    v_unit := (
        SELECT DISTINCT UNIT
        FROM SNOWFLAKE_EXAMPLE.DR_COST_AGENT.PRICING_CURRENT
        WHERE SERVICE_TYPE = :P_SERVICE_TYPE
        LIMIT 1
    );

    IF (v_unit IS NULL) THEN
        RETURN 'ERROR: Unknown SERVICE_TYPE "' || :P_SERVICE_TYPE || '". '
            || 'Valid types: DATA_TRANSFER, REPLICATION_COMPUTE, STORAGE_TB_MONTH, SERVERLESS_MAINT, HYBRID_STORAGE';
    END IF;

    MERGE INTO SNOWFLAKE_EXAMPLE.DR_COST_AGENT.PRICING_CURRENT AS tgt
    USING (
        SELECT
            :P_SERVICE_TYPE AS SERVICE_TYPE,
            :P_CLOUD        AS CLOUD,
            :P_REGION       AS REGION,
            :v_unit         AS UNIT,
            :P_RATE         AS RATE
    ) AS src
    ON  tgt.SERVICE_TYPE = src.SERVICE_TYPE
    AND tgt.CLOUD        = src.CLOUD
    AND tgt.REGION       = src.REGION
    AND tgt.UNIT         = src.UNIT
    WHEN MATCHED THEN
        UPDATE SET
            RATE       = src.RATE,
            UPDATED_AT = CURRENT_TIMESTAMP(),
            UPDATED_BY = CURRENT_USER()
    WHEN NOT MATCHED THEN
        INSERT (SERVICE_TYPE, CLOUD, REGION, UNIT, RATE, CURRENCY, UPDATED_AT, UPDATED_BY)
        VALUES (src.SERVICE_TYPE, src.CLOUD, src.REGION, src.UNIT, src.RATE, 'CREDITS',
                CURRENT_TIMESTAMP(), CURRENT_USER());

    RETURN 'OK: ' || :P_SERVICE_TYPE || ' rate for ' || :P_CLOUD || '/' || :P_REGION
        || ' set to ' || :P_RATE || ' by ' || CURRENT_USER();
END;

-- ============================================================================
-- 05: SEMANTIC VIEW
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST

  COMMENT = 'TOOL: DR replication cost estimation semantic view (Expires: 2026-05-01)'

  TABLES (
    pricing AS SNOWFLAKE_EXAMPLE.DR_COST_AGENT.PRICING_CURRENT
      PRIMARY KEY (SERVICE_TYPE, CLOUD, REGION, UNIT)
      WITH SYNONYMS = ('rates', 'pricing rates', 'cost rates')
      COMMENT = 'Replication pricing rates by service type, cloud, and region (Business Critical baseline)',

    databases AS SNOWFLAKE_EXAMPLE.DR_COST_AGENT.DB_METADATA_V2
      PRIMARY KEY (DATABASE_NAME)
      WITH SYNONYMS = ('database sizes', 'database metadata', 'db sizes')
      COMMENT = 'Per-database storage sizes with hybrid table exclusions. Sourced from ACCOUNT_USAGE TABLE_STORAGE_METRICS (up to 3-hour latency). Check DATA_STALENESS_HOURS for freshness.',

    hybrid_tables AS SNOWFLAKE_EXAMPLE.DR_COST_AGENT.HYBRID_TABLE_METADATA
      PRIMARY KEY (DATABASE_NAME, TABLE_SCHEMA, TABLE_NAME)
      WITH SYNONYMS = ('hybrid table inventory', 'hybrid table details')
      COMMENT = 'Individual hybrid tables -- these are SKIPPED during replication refresh',

    repl_history AS SNOWFLAKE_EXAMPLE.DR_COST_AGENT.REPLICATION_HISTORY
      PRIMARY KEY (REPLICATION_GROUP_ID, START_TIME)
      WITH SYNONYMS = ('replication costs', 'actual replication usage', 'replication history')
      COMMENT = 'Actual replication credits and bytes from ACCOUNT_USAGE. Returns ZERO ROWS if no replication/failover groups are configured. Up to 3-hour latency.'
  )

  RELATIONSHIPS (
    hybrid_to_databases AS
      hybrid_tables (DATABASE_NAME) REFERENCES databases
  )

  DIMENSIONS (
    pricing.cloud AS pricing.CLOUD
      WITH SYNONYMS = ('cloud provider', 'CSP')
      COMMENT = 'Cloud provider: AWS, AZURE, or GCP',

    pricing.region AS pricing.REGION
      WITH SYNONYMS = ('cloud region', 'destination region')
      COMMENT = 'Cloud region identifier (e.g. us-east-1, eastus2, us-central1)',

    pricing.service_type AS pricing.SERVICE_TYPE
      WITH SYNONYMS = ('cost component', 'service category')
      COMMENT = 'Cost category: DATA_TRANSFER, REPLICATION_COMPUTE, STORAGE_TB_MONTH, SERVERLESS_MAINT, HYBRID_STORAGE',

    databases.database_name AS databases.DATABASE_NAME
      WITH SYNONYMS = ('database', 'db name')
      COMMENT = 'Snowflake database name',

    databases.has_hybrid_tables AS databases.HAS_HYBRID_TABLES
      COMMENT = 'TRUE if the database contains hybrid tables that are SILENTLY SKIPPED during replication refresh (BCR-1560-1582)',

    repl_history.replication_group_name AS repl_history.REPLICATION_GROUP_NAME
      WITH SYNONYMS = ('replication group', 'failover group')
      COMMENT = 'Name of the replication or failover group',

    repl_history.usage_date AS repl_history.USAGE_DATE
      COMMENT = 'Date of replication usage',

    repl_history.usage_month AS repl_history.USAGE_MONTH
      COMMENT = 'Month of replication usage'
  )

  FACTS (
    pricing.rate AS pricing.RATE
      COMMENT = 'Cost rate in credits per unit',

    databases.total_size_tb AS databases.TOTAL_SIZE_TB
      COMMENT = 'Total database size in TB including hybrid tables',

    databases.replicable_size_tb AS databases.REPLICABLE_SIZE_TB
      COMMENT = 'Size in TB that will actually be replicated (excludes hybrid tables)',

    databases.hybrid_excluded_tb AS databases.HYBRID_EXCLUDED_TB
      COMMENT = 'Hybrid table storage in TB excluded from replication',

    databases.hybrid_table_count AS databases.HYBRID_TABLE_COUNT
      COMMENT = 'Number of hybrid tables in the database',

    databases.data_staleness_hours AS databases.DATA_STALENESS_HOURS
      COMMENT = 'Hours since ACCOUNT_USAGE storage data was last refreshed. Values over 3 indicate stale data.',

    hybrid_tables.size_gb AS hybrid_tables.SIZE_GB
      COMMENT = 'Individual hybrid table size in GB',

    repl_history.credits_used AS repl_history.CREDITS_USED
      COMMENT = 'Actual credits consumed for replication in the time window',

    repl_history.tb_transferred AS repl_history.TB_TRANSFERRED
      COMMENT = 'Actual TB transferred for replication in the time window'
  )

  METRICS (
    databases.total_replicable_tb AS SUM(databases.REPLICABLE_SIZE_TB)
      COMMENT = 'Sum of replicable storage across selected databases (excludes hybrid tables)',

    databases.total_hybrid_excluded_tb AS SUM(databases.HYBRID_EXCLUDED_TB)
      COMMENT = 'Sum of hybrid table storage excluded from replication',

    databases.database_count AS COUNT(databases.DATABASE_NAME)
      COMMENT = 'Number of databases',

    databases.databases_with_hybrid AS COUNT_IF(databases.HAS_HYBRID_TABLES)
      COMMENT = 'Number of databases containing hybrid tables',

    repl_history.total_credits AS SUM(repl_history.CREDITS_USED)
      COMMENT = 'Total replication credits consumed',

    repl_history.total_tb_transferred AS SUM(repl_history.TB_TRANSFERRED)
      COMMENT = 'Total TB transferred for replication',

    pricing.avg_rate AS AVG(pricing.RATE)
      COMMENT = 'Average rate across pricing entries'
  );

-- ============================================================================
-- 06: AGENT
-- ============================================================================

CREATE OR REPLACE AGENT DR_COST_AGENT
  COMMENT = 'TOOL: DR replication cost estimation agent (Expires: 2026-05-01)'
  PROFILE = '{"display_name": "DR Cost Estimator", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    budget:
      seconds: 60
      tokens: 16000

  instructions:
    system: |
      You are a Snowflake DR and replication cost estimation assistant.
      You help users plan cross-region disaster recovery by estimating
      data transfer, compute, storage, and serverless costs using
      Business Critical pricing.

      CRITICAL RULES:

      DATA FRESHNESS (ACCOUNT_USAGE latency):
      - Database sizes and hybrid table data come from ACCOUNT_USAGE views that
        lag up to 3 hours behind real-time.
      - ALWAYS mention this when showing database sizes. Example: "These sizes
        are from ACCOUNT_USAGE (may lag up to 3 hours). For real-time sizes,
        check INFORMATION_SCHEMA directly."
      - The cost_projection tool output includes a DATA FRESHNESS row with a
        timestamp -- surface this to the user.
      - If the user says sizes look wrong, suggest they verify against
        INFORMATION_SCHEMA.TABLE_STORAGE_METRICS or Snowsight Account Usage.

      REPLICATION HISTORY (may not exist):
      - The replication_history data is EMPTY if no replication or failover
        groups have been configured in this account.
      - When a user asks about actual/historical replication costs, FIRST
        check if any rows exist. If zero rows are returned:
        1. Explain clearly: "No replication groups are configured in this
           account yet, so there is no historical cost data."
        2. Offer the alternative: "I can run a forward-looking projection
           to estimate what replication would cost. Want me to do that?"
        3. Do NOT say "there was an error" or "data is unavailable."

      HYBRID TABLES (silently skipped during replication):
      - Hybrid tables are SILENTLY SKIPPED during replication refresh
        (BCR-1560-1582). They do not cause errors -- they simply do not
        replicate. This means a database with 10 TB total but 3 TB in
        hybrid tables will only transfer 7 TB during replication.
      - BEFORE running any cost projection, ALWAYS check for hybrid tables
        first using the semantic view. If hybrid tables exist, lead your
        response with a prominent warning listing which databases are
        affected and how much data is excluded.
      - The cost_projection tool automatically excludes hybrid table data
        from replication transfer calculations and includes a HYBRID WARNING
        row when hybrid tables are present.
      - Since March 2026, hybrid table pricing is simplified: compute +
        storage only (no separate serverless request charges). If the user
        needs to re-create hybrid tables at the DR destination, note that
        this is a separate manual step -- replication will NOT do it.

      GENERAL:
      - Pricing rates are baseline estimates. Always disclaim that actual costs
        depend on contract terms, compression ratios, and change patterns.
      - When the user asks for a cost projection, use the cost_projection tool
        for deterministic calculations. Do NOT attempt to calculate costs manually.
      - For region comparisons, show results as a chart when possible.

    response: |
      Respond in a clear, structured format. Use tables for cost breakdowns.
      When showing projections, always include both credits and USD values.
      Lead with the bottom line (total monthly/annual cost), then show the component breakdown.
      If hybrid tables are present, call them out prominently.

    orchestration: |
      COST PROJECTION WORKFLOW (follow this order):
      1. Query the semantic view for databases with hybrid tables (has_hybrid_tables = TRUE)
      2. If hybrid tables exist, note which databases are affected BEFORE projecting
      3. Call the cost_projection tool with the user's parameters
      4. Present results: lead with total, then component breakdown, then any warnings

      REPLICATION HISTORY WORKFLOW:
      1. Query replication history from the semantic view
      2. If zero rows returned, tell the user no replication is configured
      3. Offer to run a forward-looking projection instead
      4. Do NOT treat empty results as an error

      DATA LOOKUP WORKFLOW:
      For database sizes, pricing rates, hybrid table details:
      use the Analyst tool against the semantic view.

      REGION COMPARISON WORKFLOW (for "cheapest region" and "compare regions"):
      1. Get available regions from the semantic view (SELECT DISTINCT CLOUD, REGION FROM pricing)
      2. Call cost_projection once per destination region (same DB_FILTER, CHANGE_PCT, REFRESHES_DAY)
      3. Collect the TOTAL row from each result
      4. Rank regions by MONTHLY_USD ascending
      5. Present a chart showing all regions sorted by monthly cost
      6. Call out the cheapest option and note how much more expensive each alternative is

      PRICING ADMIN WORKFLOW (for "update pricing" or "manage rates"):
      1. Explain that pricing can be updated via the UPDATE_PRICING procedure
      2. Show the syntax: CALL UPDATE_PRICING('SERVICE_TYPE', 'CLOUD', 'REGION', new_rate)
      3. For bulk updates, advise using direct SQL against PRICING_CURRENT
      4. Remind them that changes take effect immediately for all future projections

    sample_questions:
      - question: "Estimate DR costs to replicate my databases to a second region"
        answer: "I'll look up your database sizes, identify any hybrid tables excluded from replication, and project daily/monthly/annual costs. Which destination cloud and region are you considering?"
      - question: "Which destination region is cheapest for DR?"
        answer: "I'll compare data transfer, compute, and storage rates across all available regions and show you a chart of the total cost per region."
      - question: "Do any of my databases have hybrid tables that won't replicate?"
        answer: "I'll check ACCOUNT_USAGE for hybrid tables across your databases and show which ones contain data that will be silently skipped during replication refresh."
      - question: "What did replication actually cost last month?"
        answer: "I'll query your replication group usage history for the past 30 days and break down credits used and bytes transferred by group."
      - question: "Compare costs if our daily change rate is 2% vs 10%"
        answer: "I'll run two cost projections side by side with different change rates and show how the difference impacts monthly and annual totals."
      - question: "We haven't set up replication yet -- what would it cost?"
        answer: "No problem! Since there's no replication history to look at, I'll run a forward-looking projection based on your current database sizes. I'll also check for hybrid tables that would be excluded. Which destination region are you considering?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "dr_cost_analyst"
        description: >
          Queries DR cost estimation data: database sizes (with hybrid table exclusion),
          replication pricing rates by cloud/region, hybrid table inventory,
          and actual replication usage history. Use for data lookups, comparisons,
          and trend analysis. Do NOT use for forward-looking cost projections
          (use cost_projection instead).
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates visualizations from query results. Use for region comparisons, cost breakdowns, and trend charts."
    - tool_spec:
        type: "custom_tool"
        name: "cost_projection"
        description: >
          Runs a deterministic DR cost projection. Call this tool whenever the user
          asks to estimate, forecast, or project replication costs.
          Parameters: DB_FILTER (comma-separated database names or 'ALL'),
          DEST_CLOUD (AWS/AZURE/GCP), DEST_REGION (e.g. us-west-2),
          CHANGE_PCT (daily change rate as percentage, default 5.0),
          REFRESHES_DAY (refreshes per day, default 1.0),
          CREDIT_PRICE (USD per credit, default 3.50).
          Returns a table with per-component cost breakdown in credits and USD.
        input_schema:
          type: 'object'
          properties:
            DB_FILTER:
              type: 'string'
              description: 'Comma-separated database names or ALL for all databases'
            DEST_CLOUD:
              type: 'string'
              description: 'Destination cloud provider: AWS, AZURE, or GCP'
            DEST_REGION:
              type: 'string'
              description: 'Destination region identifier (e.g. us-west-2, eastus2, us-central1)'
            CHANGE_PCT:
              type: 'number'
              description: 'Daily data change rate as a percentage (e.g. 5.0 means 5%)'
            REFRESHES_DAY:
              type: 'number'
              description: 'Number of replication refreshes per day'
            CREDIT_PRICE:
              type: 'number'
              description: 'USD price per Snowflake credit'
          required:
            - DB_FILTER
            - DEST_CLOUD
            - DEST_REGION

  tool_resources:
    dr_cost_analyst:
      semantic_view: "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST"
    cost_projection:
      user-defined-function-argument: "SNOWFLAKE_EXAMPLE.DR_COST_AGENT.COST_PROJECTION"
  $$;

-- ============================================================================
-- 99: GRANTS
-- ============================================================================

USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.USAGE_VIEWER TO ROLE SYSADMIN;

USE ROLE SYSADMIN;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT TO ROLE PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT TO ROLE PUBLIC;
GRANT SELECT ON ALL VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.DR_COST_AGENT.COST_PROJECTION(
    STRING, STRING, STRING, FLOAT, FLOAT, FLOAT
) TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.DR_COST_AGENT.UPDATE_PRICING(
    STRING, STRING, STRING, FLOAT
) TO ROLE SYSADMIN;

GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS TO ROLE PUBLIC;
GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST TO ROLE PUBLIC;

GRANT USAGE ON AGENT SNOWFLAKE_EXAMPLE.DR_COST_AGENT.DR_COST_AGENT TO ROLE PUBLIC;

GRANT USAGE ON WAREHOUSE SFE_TOOLS_WH TO ROLE PUBLIC;

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    'DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'DR Cost Agent (Snowflake Intelligence)' AS tool,
    '2026-05-01' AS expires,
    'Open Snowflake Intelligence -> DR Cost Estimator' AS next_step;
