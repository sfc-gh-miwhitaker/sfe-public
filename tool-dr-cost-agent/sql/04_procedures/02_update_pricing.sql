/******************************************************************************
 * DR Cost Agent - UPDATE_PRICING SPROC
 * Admin interface for updating pricing rates without direct table access.
 * Updates an existing row or inserts a new one (MERGE).
 *
 * Parameters:
 *   P_SERVICE_TYPE - Service type (DATA_TRANSFER, REPLICATION_COMPUTE, etc.)
 *   P_CLOUD        - Cloud provider (AWS, AZURE, GCP)
 *   P_REGION       - Region identifier (e.g. us-east-1, eastus2)
 *   P_RATE         - New rate value
 *
 * Example:
 *   CALL UPDATE_PRICING('DATA_TRANSFER', 'AWS', 'us-east-1', 2.75);
 ******************************************************************************/

USE SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT;

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
