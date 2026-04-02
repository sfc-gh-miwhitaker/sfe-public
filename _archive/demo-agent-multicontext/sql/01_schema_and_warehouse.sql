/*==============================================================================
01 - Schema and Warehouse Setup
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-02
==============================================================================*/

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS AGENT_MULTICONTEXT
  COMMENT = 'DEMO: Multi-context agent with per-request instructions (Expires: 2026-04-02)';

USE SCHEMA AGENT_MULTICONTEXT;

CREATE WAREHOUSE IF NOT EXISTS SFE_AGENT_MULTICONTEXT_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 120
  COMMENT = 'DEMO: Agent multicontext compute (Expires: 2026-04-02)';
