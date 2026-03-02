/*==============================================================================
Create Core Demo Objects
teams-agent-uni | Expires: 2026-04-01

Creates: SNOWFLAKE_EXAMPLE database, TEAMS_AGENT_UNI schema,
         SFE_TEAMS_AGENT_UNI_WH warehouse
==============================================================================*/

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'DEMO: Repository for example/demo projects - NOT FOR PRODUCTION (Expires: 2026-04-01)';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI
    COMMENT = 'DEMO: teams-agent-uni - Cortex Agents for Microsoft Teams & M365 Copilot (Expires: 2026-04-01)';

CREATE WAREHOUSE IF NOT EXISTS SFE_TEAMS_AGENT_UNI_WH WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'DEMO: teams-agent-uni - Compute for Cortex Agent queries (Expires: 2026-04-01)';

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA TEAMS_AGENT_UNI;
USE WAREHOUSE SFE_TEAMS_AGENT_UNI_WH;

SELECT CURRENT_DATABASE() AS db, CURRENT_SCHEMA() AS schema, CURRENT_WAREHOUSE() AS wh;
