/*==============================================================================
CAMPAIGN CLASSIFIER (Cortex ML CLASSIFICATION)
Generated from prompt: "Train a SNOWFLAKE.ML.CLASSIFICATION model on historical
  campaign responses joined to player features. Create a procedure that scores
  all players for a given campaign type."
Tool: Cursor + Claude | Refined: 2 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

----------------------------------------------------------------------
-- 1. Training view: campaign responses joined to player features
----------------------------------------------------------------------
CREATE OR REPLACE VIEW V_CLASSIFICATION_TRAINING
    COMMENT = 'DEMO: Training data for campaign response classifier (Expires: 2026-05-01)'
AS
SELECT
    f.avg_daily_wager,
    f.session_frequency,
    f.avg_session_duration,
    f.win_rate,
    f.slots_pct,
    f.table_pct,
    f.poker_pct,
    f.sportsbook_pct,
    f.weekend_pct,
    f.mobile_pct,
    f.days_since_last_visit,
    f.lifetime_wagered,
    f.loyalty_tier_num,
    f.avg_bet_size,
    f.visit_consistency,
    f.game_diversity,
    c.campaign_type,
    r.responded
FROM RAW_CAMPAIGN_RESPONSES r
JOIN DT_PLAYER_FEATURES f ON r.player_id = f.player_id
JOIN RAW_CAMPAIGNS c ON r.campaign_id = c.campaign_id;

----------------------------------------------------------------------
-- 2. Train ML CLASSIFICATION model
----------------------------------------------------------------------
CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION CAMPAIGN_RESPONSE_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_CLASSIFICATION_TRAINING'),
    TARGET_COLNAME => 'RESPONDED'
)
COMMENT = 'DEMO: Predicts player campaign response probability (Expires: 2026-05-01)';

----------------------------------------------------------------------
-- 3. Scoring procedure: rank players by predicted response probability
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SCORE_CAMPAIGN_AUDIENCE(CAMPAIGN_TYPE VARCHAR)
RETURNS TABLE (
    player_id         NUMBER,
    name              VARCHAR,
    loyalty_tier      VARCHAR,
    predicted_response BOOLEAN,
    response_probability FLOAT,
    avg_daily_wager   FLOAT,
    lifetime_wagered  FLOAT,
    days_since_last_visit NUMBER
)
LANGUAGE SQL
COMMENT = 'DEMO: Score all players for campaign targeting, return top 50 (Expires: 2026-05-01)'
AS
DECLARE
    res RESULTSET;
BEGIN
    res := (
        WITH scored AS (
            SELECT
                f.player_id,
                p.name,
                p.loyalty_tier,
                f.avg_daily_wager,
                f.session_frequency,
                f.avg_session_duration,
                f.win_rate,
                f.slots_pct,
                f.table_pct,
                f.poker_pct,
                f.sportsbook_pct,
                f.weekend_pct,
                f.mobile_pct,
                f.days_since_last_visit,
                f.lifetime_wagered,
                f.loyalty_tier_num,
                f.avg_bet_size,
                f.visit_consistency,
                f.game_diversity,
                :CAMPAIGN_TYPE AS campaign_type
            FROM DT_PLAYER_FEATURES f
            JOIN RAW_PLAYERS p ON f.player_id = p.player_id
        ),
        predictions AS (
            SELECT
                player_id,
                name,
                loyalty_tier,
                avg_daily_wager,
                lifetime_wagered,
                days_since_last_visit,
                CAMPAIGN_RESPONSE_MODEL!PREDICT(
                    INPUT_DATA => OBJECT_CONSTRUCT(
                        'AVG_DAILY_WAGER',       avg_daily_wager,
                        'SESSION_FREQUENCY',     session_frequency,
                        'AVG_SESSION_DURATION',  avg_session_duration,
                        'WIN_RATE',              win_rate,
                        'SLOTS_PCT',             slots_pct,
                        'TABLE_PCT',             table_pct,
                        'POKER_PCT',             poker_pct,
                        'SPORTSBOOK_PCT',        sportsbook_pct,
                        'WEEKEND_PCT',           weekend_pct,
                        'MOBILE_PCT',            mobile_pct,
                        'DAYS_SINCE_LAST_VISIT', days_since_last_visit,
                        'LIFETIME_WAGERED',      lifetime_wagered,
                        'LOYALTY_TIER_NUM',      loyalty_tier_num,
                        'AVG_BET_SIZE',          avg_bet_size,
                        'VISIT_CONSISTENCY',     visit_consistency,
                        'GAME_DIVERSITY',        game_diversity,
                        'CAMPAIGN_TYPE',         campaign_type
                    )
                ) AS prediction
            FROM scored
        )
        SELECT
            player_id,
            name,
            loyalty_tier,
            prediction:class::BOOLEAN AS predicted_response,
            prediction:probability:True::FLOAT AS response_probability,
            avg_daily_wager::FLOAT AS avg_daily_wager,
            lifetime_wagered::FLOAT AS lifetime_wagered,
            days_since_last_visit
        FROM predictions
        WHERE prediction:class::BOOLEAN = TRUE
        ORDER BY response_probability DESC
    );
    RETURN TABLE(res);
END;
