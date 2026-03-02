/*==============================================================================
CAMPAIGN RECOMMENDATIONS (Cortex COMPLETE)
Generated from prompt: "Use SNOWFLAKE.CORTEX.COMPLETE to generate campaign
  messaging and channel strategy recommendations given an audience profile."
Tool: Cursor + Claude | Refined: 1 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

----------------------------------------------------------------------
-- Function: generate campaign recommendation for a given campaign type
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION GENERATE_CAMPAIGN_RECOMMENDATION(
    campaign_type VARCHAR,
    avg_wager FLOAT,
    avg_tier FLOAT,
    avg_frequency FLOAT,
    top_game_type VARCHAR,
    audience_size NUMBER
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: LLM-powered campaign recommendation generator (Expires: 2026-05-01)'
AS
$$
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large2',
        'You are a casino marketing strategist. Generate a concise campaign recommendation '
        || '(3-4 sentences) for a ' || campaign_type || ' campaign targeting '
        || audience_size::VARCHAR || ' players. '
        || 'Audience profile: average daily wager $' || ROUND(avg_wager, 0)::VARCHAR
        || ', average loyalty tier ' || ROUND(avg_tier, 1)::VARCHAR || '/5'
        || ', average ' || ROUND(avg_frequency, 1)::VARCHAR || ' sessions/week'
        || ', most popular game type: ' || top_game_type || '. '
        || 'Include: recommended offer, preferred channel (email/SMS/app push/in-venue), '
        || 'and optimal timing. Be specific and data-driven.'
    )
$$;

----------------------------------------------------------------------
-- View: campaign recommendations with audience profiles
----------------------------------------------------------------------
CREATE OR REPLACE VIEW V_CAMPAIGN_RECOMMENDATIONS
    COMMENT = 'DEMO: Aggregated audience profiles per campaign type for LLM recommendations (Expires: 2026-05-01)'
AS
WITH audience_profiles AS (
    SELECT
        c.campaign_type,
        COUNT(DISTINCT r.player_id) AS audience_size,
        AVG(f.avg_daily_wager)      AS avg_wager,
        AVG(f.loyalty_tier_num)     AS avg_tier,
        AVG(f.session_frequency)    AS avg_frequency
    FROM RAW_CAMPAIGN_RESPONSES r
    JOIN RAW_CAMPAIGNS c ON r.campaign_id = c.campaign_id
    JOIN DT_PLAYER_FEATURES f ON r.player_id = f.player_id
    WHERE r.responded = TRUE
    GROUP BY c.campaign_type
),
top_games AS (
    SELECT
        c.campaign_type,
        a.game_type,
        COUNT(*) AS play_count,
        ROW_NUMBER() OVER (PARTITION BY c.campaign_type ORDER BY COUNT(*) DESC) AS rn
    FROM RAW_CAMPAIGN_RESPONSES r
    JOIN RAW_CAMPAIGNS c ON r.campaign_id = c.campaign_id
    JOIN RAW_PLAYER_ACTIVITY a ON r.player_id = a.player_id
    WHERE r.responded = TRUE
    GROUP BY c.campaign_type, a.game_type
    QUALIFY rn = 1
)
SELECT
    ap.campaign_type,
    ap.audience_size,
    ap.avg_wager,
    ap.avg_tier,
    ap.avg_frequency,
    tg.game_type AS top_game_type
FROM audience_profiles ap
JOIN top_games tg ON ap.campaign_type = tg.campaign_type;
