/******************************************************************************
 * DR Cost Agent - Schema & Warehouse Setup
 ******************************************************************************/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_TOOLS_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.DR_COST_AGENT
    COMMENT = 'TOOL: DR/replication cost estimation agent (Expires: 2026-05-01)';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
    COMMENT = 'Shared schema for semantic views across demo projects | Author: SE Community';

USE SCHEMA SNOWFLAKE_EXAMPLE.DR_COST_AGENT;
