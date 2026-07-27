/*==============================================================================
TEARDOWN — Artist Analytics
Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

Drops all demo objects. The shared SNOWFLAKE_EXAMPLE database is preserved.

INSTRUCTIONS:
  1. Open Snowsight → New Worksheet
  2. Paste this entire file
  3. Click "Run All"
==============================================================================*/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- ── Cortex Agent ──────────────────────────────────────────────────────────────
DROP AGENT IF EXISTS SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.ARTIST_ANALYTICS_AGENT;

-- ── Semantic View ─────────────────────────────────────────────────────────────
DROP SEMANTIC VIEW IF EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_ARTIST_ANALYTICS;

-- ── Streamlit ─────────────────────────────────────────────────────────────────
DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.ARTIST_DASHBOARD;

-- ── Schema (drops all tables and views in one step) ───────────────────────────
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;

-- ── Warehouse ─────────────────────────────────────────────────────────────────
DROP WAREHOUSE IF EXISTS SFE_ARTIST_ANALYTICS_WH;

SELECT 'Teardown complete. SNOWFLAKE_EXAMPLE database preserved.' AS teardown_status;
