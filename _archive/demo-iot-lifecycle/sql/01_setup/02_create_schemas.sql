USE DATABASE SNOWFLAKE_EXAMPLE;
USE WAREHOUSE SFE_IOT_LIFECYCLE_WH;

CREATE SCHEMA IF NOT EXISTS IOT_LIFECYCLE
  COMMENT = 'DEMO: IoT Lifecycle -- fleet tracking, RFID garments, financials (Expires: 2026-06-11)';

CREATE SCHEMA IF NOT EXISTS SEMANTIC_MODELS
  COMMENT = 'Shared schema for semantic views across demo projects';
