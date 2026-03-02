/*==============================================================================
PLAYER FEATURES (Dynamic Table)
Generated from prompt: "Create a feature engineering pipeline that computes
  16 behavioral metrics per player using Dynamic Tables."
Tool: Cursor + Claude | Refined: 2 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

CREATE OR REPLACE DYNAMIC TABLE DT_PLAYER_FEATURES
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_CAMPAIGN_ENGINE_WH
    COMMENT = 'DEMO: 16 behavioral features per player, auto-refreshed (Expires: 2026-04-01)'
AS
WITH activity_stats AS (
    SELECT
        a.player_id,
        COUNT(*)                                                    AS total_sessions,
        COUNT(DISTINCT a.activity_date)                             AS distinct_days,
        SUM(a.total_wagered)                                        AS lifetime_wagered,
        AVG(a.total_wagered)                                        AS avg_bet_size,
        AVG(a.session_duration_min)                                 AS avg_session_duration,
        SUM(a.total_wagered) / NULLIF(COUNT(DISTINCT a.activity_date), 0)
                                                                    AS avg_daily_wager,
        SUM(a.total_won) / NULLIF(SUM(a.total_wagered), 0)         AS win_rate,
        COUNT(DISTINCT a.activity_date) * 7.0
            / NULLIF(DATEDIFF('day', MIN(a.activity_date), MAX(a.activity_date)), 0)
                                                                    AS session_frequency,
        SUM(CASE WHEN a.game_type = 'SLOTS'       THEN 1 ELSE 0 END) * 1.0
            / NULLIF(COUNT(*), 0)                                   AS slots_pct,
        SUM(CASE WHEN a.game_type = 'TABLE_GAMES'  THEN 1 ELSE 0 END) * 1.0
            / NULLIF(COUNT(*), 0)                                   AS table_pct,
        SUM(CASE WHEN a.game_type = 'POKER'        THEN 1 ELSE 0 END) * 1.0
            / NULLIF(COUNT(*), 0)                                   AS poker_pct,
        SUM(CASE WHEN a.game_type = 'SPORTS_BOOK'  THEN 1 ELSE 0 END) * 1.0
            / NULLIF(COUNT(*), 0)                                   AS sportsbook_pct,
        SUM(CASE WHEN DAYOFWEEK(a.activity_date) IN (0, 6) THEN 1 ELSE 0 END) * 1.0
            / NULLIF(COUNT(*), 0)                                   AS weekend_pct,
        SUM(CASE WHEN a.device = 'MOBILE' THEN 1 ELSE 0 END) * 1.0
            / NULLIF(COUNT(*), 0)                                   AS mobile_pct,
        DATEDIFF('day', MAX(a.activity_date), CURRENT_DATE())       AS days_since_last_visit,
        STDDEV(a.total_wagered) / NULLIF(AVG(a.total_wagered), 0)   AS visit_consistency_cv,
        COUNT(DISTINCT a.game_type)                                 AS game_diversity
    FROM RAW_PLAYER_ACTIVITY a
    GROUP BY a.player_id
)
SELECT
    p.player_id,
    p.loyalty_tier,
    COALESCE(s.avg_daily_wager, 0)          AS avg_daily_wager,
    COALESCE(s.session_frequency, 0)        AS session_frequency,
    COALESCE(s.avg_session_duration, 0)     AS avg_session_duration,
    COALESCE(s.win_rate, 0)                 AS win_rate,
    COALESCE(s.slots_pct, 0)               AS slots_pct,
    COALESCE(s.table_pct, 0)               AS table_pct,
    COALESCE(s.poker_pct, 0)               AS poker_pct,
    COALESCE(s.sportsbook_pct, 0)          AS sportsbook_pct,
    COALESCE(s.weekend_pct, 0)             AS weekend_pct,
    COALESCE(s.mobile_pct, 0)              AS mobile_pct,
    COALESCE(s.days_since_last_visit, 999) AS days_since_last_visit,
    COALESCE(s.lifetime_wagered, 0)        AS lifetime_wagered,
    CASE p.loyalty_tier
        WHEN 'Bronze'   THEN 1
        WHEN 'Silver'   THEN 2
        WHEN 'Gold'     THEN 3
        WHEN 'Platinum' THEN 4
        WHEN 'Diamond'  THEN 5
        ELSE 0
    END                                     AS loyalty_tier_num,
    COALESCE(s.avg_bet_size, 0)            AS avg_bet_size,
    COALESCE(1.0 - s.visit_consistency_cv, 0) AS visit_consistency,
    COALESCE(s.game_diversity, 0)          AS game_diversity
FROM RAW_PLAYERS p
LEFT JOIN activity_stats s ON p.player_id = s.player_id;
