/*==============================================================================
SETUP - Gaming Player Analytics
Creates project schema and warehouse.
==============================================================================*/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS GAMING_PLAYER_ANALYTICS
  COMMENT = 'DEMO: Player behavior analytics with AI enrichment for indie gaming studio (Expires: 2026-04-24)';

USE SCHEMA GAMING_PLAYER_ANALYTICS;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared schema for semantic views across demo projects';
