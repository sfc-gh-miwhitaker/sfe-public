/******************************************************************************
 * DR Cost Agent - REPLICATION_HISTORY
 * Wraps ACCOUNT_USAGE replication views for backward-looking cost analysis.
 * Returns empty if no replication groups exist (the agent handles this gracefully).
 ******************************************************************************/

USE SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT;

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
