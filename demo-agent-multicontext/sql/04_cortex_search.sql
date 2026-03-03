/*==============================================================================
04 - Cortex Search Service for Support Knowledge Base
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-02
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA AGENT_MULTICONTEXT;
USE WAREHOUSE SFE_AGENT_MULTICONTEXT_WH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SUPPORT_KB_SEARCH
  ON content
  ATTRIBUTES category, station_id, title
  WAREHOUSE = SFE_AGENT_MULTICONTEXT_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'DEMO: Support article search for TV network agent (Expires: 2026-04-02)'
AS (
  SELECT
    article_id,
    station_id,
    category,
    title,
    content,
    last_updated
  FROM SUPPORT_ARTICLES
);
