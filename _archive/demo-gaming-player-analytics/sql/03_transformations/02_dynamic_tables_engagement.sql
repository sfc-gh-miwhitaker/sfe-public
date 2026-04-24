/*==============================================================================
SESSION METRICS + ENGAGEMENT FEATURES - Dynamic Tables
DT_SESSION_METRICS: per-player daily session aggregates.
DT_ENGAGEMENT_FEATURES: rolling engagement indicators (uses DOWNSTREAM lag).
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS;
USE WAREHOUSE SFE_GAMING_PLAYER_ANALYTICS_WH;

CREATE OR REPLACE DYNAMIC TABLE DT_SESSION_METRICS
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_GAMING_PLAYER_ANALYTICS_WH
  COMMENT = 'DEMO: Daily session aggregates per player (Expires: 2026-04-24)'
AS
SELECT
    player_id,
    event_date,
    COUNT(DISTINCT session_id) AS session_count,
    SUM(CASE WHEN event_type = 'session_end' AND duration_seconds IS NOT NULL
             THEN duration_seconds ELSE 0 END) / 60.0 AS total_playtime_minutes,
    COUNT(CASE WHEN event_type = 'level_complete' THEN 1 END) AS levels_completed,
    COUNT(CASE WHEN event_type = 'ad_view' THEN 1 END) AS ads_viewed,
    MAX(CASE WHEN event_type = 'level_complete' THEN level_id END) AS max_level_reached
FROM RAW_PLAYER_EVENTS
GROUP BY player_id, event_date;

CREATE OR REPLACE DYNAMIC TABLE DT_ENGAGEMENT_FEATURES
  TARGET_LAG = DOWNSTREAM
  WAREHOUSE = SFE_GAMING_PLAYER_ANALYTICS_WH
  COMMENT = 'DEMO: Rolling engagement features for churn risk scoring (Expires: 2026-04-24)'
AS
WITH daily_active AS (
    SELECT
        player_id,
        event_date,
        session_count,
        total_playtime_minutes,
        levels_completed,
        ads_viewed
    FROM DT_SESSION_METRICS
),
player_rolling AS (
    SELECT
        player_id,
        COUNT(DISTINCT event_date) AS active_days_last_30,
        SUM(session_count) AS sessions_last_30,
        ROUND(AVG(total_playtime_minutes), 1) AS avg_daily_playtime_minutes,
        SUM(levels_completed) AS levels_last_30,
        SUM(ads_viewed) AS ads_viewed_last_30,
        MAX(event_date) AS last_play_date,
        DATEDIFF('day', MAX(event_date), CURRENT_DATE()) AS days_since_last_play
    FROM daily_active
    WHERE event_date >= DATEADD('day', -30, CURRENT_DATE())
    GROUP BY player_id
),
monthly_active AS (
    SELECT COUNT(DISTINCT player_id) AS mau
    FROM daily_active
    WHERE event_date >= DATEADD('day', -30, CURRENT_DATE())
)
SELECT
    r.player_id,
    r.active_days_last_30,
    r.sessions_last_30,
    r.avg_daily_playtime_minutes,
    r.levels_last_30,
    r.ads_viewed_last_30,
    r.last_play_date,
    r.days_since_last_play,
    ROUND(r.active_days_last_30 / 30.0, 3) AS dau_mau_ratio,
    CASE
        WHEN r.days_since_last_play > 14 THEN 'High'
        WHEN r.days_since_last_play > 7  THEN 'Medium'
        ELSE 'Low'
    END AS churn_risk_level
FROM player_rolling r
CROSS JOIN monthly_active m;
