/*==============================================================================
AI ENRICHMENT - Campaign Dimension with Cortex AI
AI_CLASSIFY auto-tags campaign types; AI_EXTRACT parses metadata from notes.
CTE ensures each AI function is called exactly once per row.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.MUSIC_MARKETING;
USE WAREHOUSE SFE_MUSIC_MARKETING_WH;

CREATE OR REPLACE DYNAMIC TABLE DIM_CAMPAIGN
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_MUSIC_MARKETING_WH
  REFRESH_MODE = INCREMENTAL
  COMMENT = 'DEMO: Campaign dimension with AI_CLASSIFY and AI_EXTRACT enrichment (Expires: 2026-04-24)'
AS
WITH ai_enriched AS (
    SELECT
        c.campaign_id,
        c.campaign_name,
        c.campaign_description,
        c.artist_id,
        c.channel,
        c.start_date,
        c.end_date,
        c.campaign_type AS original_campaign_type,
        c.territory     AS original_territory,

        AI_CLASSIFY(
            c.campaign_description,
            ['Single Launch', 'Album Cycle', 'Playlist Push', 'Tour Support', 'TikTok Promo'],
            {'task_description': 'Classify this music marketing campaign based on its description'}
        ):labels[0]::VARCHAR AS ai_campaign_type,

        AI_EXTRACT(
            text => COALESCE(c.campaign_description, '') || ' ' || COALESCE(c.notes, ''),
            responseFormat => {
                'territory': 'What geographic territory or region is this campaign targeting?',
                'genre': 'What music genre is mentioned?',
                'priority': 'What is the priority level (HIGH, MEDIUM, LOW)?'
            }
        ):response AS ai_extracted_metadata

    FROM RAW_CAMPAIGNS c
)
SELECT
    campaign_id,
    campaign_name,
    campaign_description,
    artist_id,
    channel,
    start_date,
    end_date,
    original_campaign_type,
    original_territory,
    ai_campaign_type,
    ai_extracted_metadata,
    COALESCE(original_campaign_type, ai_campaign_type) AS resolved_campaign_type,
    COALESCE(original_territory, ai_extracted_metadata:territory::VARCHAR) AS resolved_territory
FROM ai_enriched;
