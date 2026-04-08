/******************************************************************************
 * DCM Post-Hook: Grants for non-DCM-managed objects
 * Procedures, semantic views, and agents can't be defined in DCM,
 * so their grants live here alongside the USAGE_VIEWER database role.
 ******************************************************************************/

-- ACCOUNT_USAGE access for views that query SNOWFLAKE.ACCOUNT_USAGE
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.USAGE_VIEWER TO ROLE SYSADMIN;

-- Grants on objects created by post-hook scripts (not DCM-managed)
USE ROLE SYSADMIN;

GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.DR_COST_AGENT.COST_PROJECTION(
    STRING, STRING, STRING, FLOAT, FLOAT, FLOAT
) TO ROLE PUBLIC;

GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.DR_COST_AGENT.UPDATE_PRICING(
    STRING, STRING, STRING, FLOAT
) TO ROLE SYSADMIN;

GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS TO ROLE PUBLIC;
GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_DR_COST TO ROLE PUBLIC;

GRANT USAGE ON AGENT SNOWFLAKE_EXAMPLE.DR_COST_AGENT.DR_COST_AGENT TO ROLE PUBLIC;
