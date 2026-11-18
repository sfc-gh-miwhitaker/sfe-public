/*==============================================================================
01_create_schema.sql - Subscription Media LTV demo
Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-16
Creates the project schema and the shared semantic model schema.
==============================================================================*/

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV
  COMMENT = 'DEMO: Subscription media member value, churn, and ad economics. All data synthetic. (Expires: 2027-01-16)';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared schema for semantic views across SE demo projects';
