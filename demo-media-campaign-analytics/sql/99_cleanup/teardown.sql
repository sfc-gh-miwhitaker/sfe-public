/*==============================================================================
  99_cleanup/teardown.sql
  Media Campaign Analytics — Drop All Project Objects
  Pair-programmed by SE Community + Cortex Code

  Strategy: DROP SCHEMA CASCADE is nuclear for everything IN the schema
  (agents, search services, tables, views, UDFs, etc.).
  We only need explicit drops for objects OUTSIDE the project schema.
==============================================================================*/

USE ROLE SYSADMIN;

-- ── Objects OUTSIDE the project schema (need explicit drops) ─────────────────

-- Semantic view lives in the shared SEMANTIC_MODELS schema
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS;

-- ── Nuclear: drop the project schema (kills everything inside it) ────────────
-- This cascades: agents, search services, tables, views, UDFs, etc.
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

-- Warehouse is an account-level object
DROP WAREHOUSE IF EXISTS SFE_MEDIA_CAMPAIGN_WH;

-- NOTE: Do NOT drop the following shared infrastructure:
--   SNOWFLAKE_EXAMPLE (database)
--   SNOWFLAKE_EXAMPLE.GIT_REPOS (schema)
--   SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS (schema — shared with other demos)
--   SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO (used by all monorepo demos)
--   SFE_GIT_API_INTEGRATION (account-level, shared)
