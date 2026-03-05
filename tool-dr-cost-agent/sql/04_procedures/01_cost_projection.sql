/******************************************************************************
 * DR Cost Agent - cost_projection SPROC
 * Custom tool for the SI agent: deterministic cost projection math.
 * Looks up rates, sizes (excluding hybrid tables), and projects costs.
 *
 * Parameters:
 *   DB_FILTER      - Comma-separated database names, or 'ALL'
 *   DEST_CLOUD     - Destination cloud provider (AWS, AZURE, GCP)
 *   DEST_REGION    - Destination region identifier
 *   CHANGE_PCT     - Daily change rate as a percentage (e.g. 5.0 = 5%)
 *   REFRESHES_DAY  - Number of replication refreshes per day
 *   CREDIT_PRICE   - USD price per credit (e.g. 3.50)
 *
 * Returns a result set with per-component cost breakdown.
 ******************************************************************************/

USE SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT;

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
            -- Data freshness advisory (always first row)
            SELECT '** DATA FRESHNESS **' AS COMPONENT,
                   0 AS DAILY_CREDITS, 0 AS MONTHLY_CREDITS, 0 AS ANNUAL_CREDITS,
                   'Storage metrics sourced from ACCOUNT_USAGE (up to 3-hour lag). '
                   || 'Queried at ' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYY-MM-DD HH24:MI TZH:TZM') AS NOTE
            -- Hybrid table advisory (only when hybrid tables present)
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
