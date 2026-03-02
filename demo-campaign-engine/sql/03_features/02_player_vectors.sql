/*==============================================================================
PLAYER VECTORS (Dynamic Table)
Generated from prompt: "Normalize all 16 features to 0-1 range using min-max
  scaling and store as VECTOR(FLOAT,16) for cosine similarity search."
Tool: Cursor + Claude | Refined: 2 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

CREATE OR REPLACE DYNAMIC TABLE DT_PLAYER_VECTORS
    TARGET_LAG = '1 hour'
    WAREHOUSE = SFE_CAMPAIGN_ENGINE_WH
    COMMENT = 'DEMO: Min-max normalized behavior vectors VECTOR(FLOAT,16) (Expires: 2026-04-01)'
AS
WITH bounds AS (
    SELECT
        MIN(avg_daily_wager)       AS min_adw,   MAX(avg_daily_wager)       AS max_adw,
        MIN(session_frequency)     AS min_sf,    MAX(session_frequency)     AS max_sf,
        MIN(avg_session_duration)  AS min_asd,   MAX(avg_session_duration)  AS max_asd,
        MIN(win_rate)              AS min_wr,    MAX(win_rate)              AS max_wr,
        MIN(slots_pct)             AS min_sp,    MAX(slots_pct)             AS max_sp,
        MIN(table_pct)             AS min_tp,    MAX(table_pct)             AS max_tp,
        MIN(poker_pct)             AS min_pp,    MAX(poker_pct)             AS max_pp,
        MIN(sportsbook_pct)        AS min_sbp,   MAX(sportsbook_pct)        AS max_sbp,
        MIN(weekend_pct)           AS min_wp,    MAX(weekend_pct)           AS max_wp,
        MIN(mobile_pct)            AS min_mp,    MAX(mobile_pct)            AS max_mp,
        MIN(days_since_last_visit) AS min_dslv,  MAX(days_since_last_visit) AS max_dslv,
        MIN(lifetime_wagered)      AS min_lw,    MAX(lifetime_wagered)      AS max_lw,
        MIN(loyalty_tier_num)      AS min_ltn,   MAX(loyalty_tier_num)      AS max_ltn,
        MIN(avg_bet_size)          AS min_abs,   MAX(avg_bet_size)          AS max_abs,
        MIN(visit_consistency)     AS min_vc,    MAX(visit_consistency)     AS max_vc,
        MIN(game_diversity)        AS min_gd,    MAX(game_diversity)        AS max_gd
    FROM DT_PLAYER_FEATURES
)
SELECT
    f.player_id,
    ARRAY_CONSTRUCT(
        (f.avg_daily_wager       - b.min_adw)  / NULLIF(b.max_adw  - b.min_adw,  0),
        (f.session_frequency     - b.min_sf)   / NULLIF(b.max_sf   - b.min_sf,   0),
        (f.avg_session_duration  - b.min_asd)  / NULLIF(b.max_asd  - b.min_asd,  0),
        (f.win_rate              - b.min_wr)   / NULLIF(b.max_wr   - b.min_wr,   0),
        (f.slots_pct             - b.min_sp)   / NULLIF(b.max_sp   - b.min_sp,   0),
        (f.table_pct             - b.min_tp)   / NULLIF(b.max_tp   - b.min_tp,   0),
        (f.poker_pct             - b.min_pp)   / NULLIF(b.max_pp   - b.min_pp,   0),
        (f.sportsbook_pct        - b.min_sbp)  / NULLIF(b.max_sbp  - b.min_sbp,  0),
        (f.weekend_pct           - b.min_wp)   / NULLIF(b.max_wp   - b.min_wp,   0),
        (f.mobile_pct            - b.min_mp)   / NULLIF(b.max_mp   - b.min_mp,   0),
        (f.days_since_last_visit - b.min_dslv) / NULLIF(b.max_dslv - b.min_dslv, 0),
        (f.lifetime_wagered      - b.min_lw)   / NULLIF(b.max_lw   - b.min_lw,   0),
        (f.loyalty_tier_num      - b.min_ltn)  / NULLIF(b.max_ltn  - b.min_ltn,  0),
        (f.avg_bet_size          - b.min_abs)  / NULLIF(b.max_abs  - b.min_abs,  0),
        (f.visit_consistency     - b.min_vc)   / NULLIF(b.max_vc   - b.min_vc,   0),
        (f.game_diversity        - b.min_gd)   / NULLIF(b.max_gd   - b.min_gd,   0)
    )::VECTOR(FLOAT, 16) AS behavior_vector
FROM DT_PLAYER_FEATURES f
CROSS JOIN bounds b;
