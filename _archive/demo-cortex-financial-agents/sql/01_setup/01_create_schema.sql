/*==============================================================================
01 - Schema and Warehouse Setup
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-09
==============================================================================*/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS FINANCIAL_AGENTS
  COMMENT = 'DEMO: Specialty finance portfolio risk agent with Cortex Analyst + Cortex Search (Expires: 2026-04-09)';

CREATE SCHEMA IF NOT EXISTS SEMANTIC_MODELS
  COMMENT = 'Shared schema for semantic views across demo projects';

USE SCHEMA FINANCIAL_AGENTS;
USE WAREHOUSE SFE_FINANCIAL_AGENTS_WH;
