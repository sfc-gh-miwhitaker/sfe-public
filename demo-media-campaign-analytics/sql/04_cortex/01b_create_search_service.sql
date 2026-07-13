/*==============================================================================
  04_cortex/01b_create_search_service.sql
  Media Campaign Analytics — Cortex Search Service
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12

  Creates a Cortex Search Service over campaign documents so the agent can
  answer qualitative questions (briefs, creative copy, strategy rationale,
  client relationship context) alongside structured analytics.
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

CREATE OR REPLACE CORTEX SEARCH SERVICE CAMPAIGN_DOCS_SEARCH
  ON content
  ATTRIBUTES doc_type, client_name, channel_name, campaign_name
  WAREHOUSE = SFE_MEDIA_CAMPAIGN_WH
  TARGET_LAG = '1 minute'
  COMMENT = 'DEMO: Campaign document search — briefs, copy, strategy notes, client context (Expires: 2026-08-12)'
AS (
  SELECT
      d.doc_id,
      d.doc_type,
      d.title,
      d.content,
      cl.client_name,
      COALESCE(ch.channel_name, 'N/A') AS channel_name,
      COALESCE(c.campaign_name, 'N/A') AS campaign_name,
      d.created_date
  FROM DOC_CAMPAIGN_CONTENT d
  JOIN DIM_CLIENT cl ON d.client_id = cl.client_id
  LEFT JOIN DIM_CAMPAIGN c ON d.campaign_id = c.campaign_id
  LEFT JOIN DIM_CHANNEL ch ON c.channel_id = ch.channel_id
);
