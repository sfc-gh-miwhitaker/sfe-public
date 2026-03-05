/******************************************************************************
 * DR Cost Agent - HYBRID_TABLE_METADATA
 * Per-database hybrid table inventory for replication exclusion analysis.
 * As of March 2026, hybrid table requests are cost-neutral (compute + storage only).
 * Hybrid tables are SKIPPED during replication refresh (BCR-1560-1582).
 ******************************************************************************/

USE SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT;

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
